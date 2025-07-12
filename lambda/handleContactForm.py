import json
import boto3
import uuid
import datetime

# Initialize AWS clients
dynamodb = boto3.resource('dynamodb')
cloudwatch = boto3.client('cloudwatch')
table = dynamodb.Table('ContactFormSubmissions')

def lambda_handler(event, context):
    print("✅ Event received:", json.dumps(event))  # CloudWatch log

    try:
        # Parse request body
        data = json.loads(event['body'])

        name = data.get('name')
        email = data.get('email')
        message = data.get('message')
        referral_code = data.get('referralCode', 'Direct')

        # Build item for DynamoDB
        item = {
            'id': str(uuid.uuid4()),
            'name': name,
            'email': email,
            'message': message,
            'referralCode': referral_code,
            'timestamp': str(datetime.datetime.utcnow())
        }

        # Store in DynamoDB
        table.put_item(Item=item)

        # ✅ Publish metrics to CloudWatch
        cloudwatch.put_metric_data(
            Namespace='Portfolio/Metrics',
            MetricData=[
                {
                    'MetricName': 'ContactSubmissions',
                    'Dimensions': [
                        {'Name': 'Page', 'Value': 'Contact'}
                    ],
                    'Unit': 'Count',
                    'Value': 1
                },
                {
                    'MetricName': 'ReferralHits',
                    'Dimensions': [
                        {'Name': 'Source', 'Value': referral_code}
                    ],
                    'Unit': 'Count',
                    'Value': 1
                }
            ]
        )

        # ✅ Successful response
        return {
            'statusCode': 200,
            'headers': {
                'Access-Control-Allow-Origin': '*',
                'Access-Control-Allow-Headers': '*'
            },
            'body': json.dumps({ 'message': 'Message sent successfully!' })
        }

    except Exception as e:
        print("❌ Error:", str(e))  # Log error to CloudWatch

        return {
            'statusCode': 500,
            'headers': {
                'Access-Control-Allow-Origin': '*',
                'Access-Control-Allow-Headers': '*'
            },
            'body': json.dumps({ 'error': 'Failed to submit form.' })
        }

