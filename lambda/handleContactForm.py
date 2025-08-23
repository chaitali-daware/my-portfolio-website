import json
import boto3
import uuid
from datetime import datetime
import os
import traceback

dynamodb = boto3.resource('dynamodb')
cloudwatch = boto3.client('cloudwatch')

CONTACT_TABLE = os.environ.get("CONTACT_TABLE", "ContactFormSubmissions")
table = dynamodb.Table(CONTACT_TABLE)

def response(code, body):
    return {
        'statusCode': code,
        'headers': {
            'Access-Control-Allow-Origin': '*',
            'Access-Control-Allow-Headers': '*',
            'Content-Type': 'application/json'
        },
        'body': json.dumps(body)
    }

def lambda_handler(event, context):
    try:
        print("Event:", event)
        body = json.loads(event.get('body', '{}'))

        name = body.get('name')
        email = body.get('email')
        message = body.get('message')
        referral_code = body.get('referralCode', 'Direct')

        if not name or not email or not message:
            return response(400, {'error': 'Missing required fields.'})

        item = {
            'id': str(uuid.uuid4()),
            'name': name,
            'email': email,
            'message': message,
            'referralCode': referral_code,
            'timestamp': datetime.utcnow().isoformat()
        }

        table.put_item(Item=item)

        try:
            cloudwatch.put_metric_data(
                Namespace='Portfolio/Metrics',
                MetricData=[
                    {'MetricName': 'ContactSubmissions', 'Dimensions': [{'Name': 'Page', 'Value': 'Contact'}], 'Unit': 'Count', 'Value': 1},
                    {'MetricName': 'ReferralHits', 'Dimensions': [{'Name': 'Source', 'Value': referral_code}], 'Unit': 'Count', 'Value': 1}
                ]
            )
        except Exception as e:
            print("CloudWatch metric publish failed:", str(e))

        return response(200, {'message': 'Message sent successfully!'})

    except Exception as e:
        print("Error:", str(e))
        traceback.print_exc()
        return response(500, {'error': 'Failed to submit form.'})
