import json
import boto3
import uuid
from datetime import datetime
import os
import traceback

dynamodb = boto3.resource('dynamodb')
cloudwatch = boto3.client('cloudwatch')

VISITOR_TABLE = os.environ.get("VISITOR_TABLE", "VisitorLogs")
table = dynamodb.Table(VISITOR_TABLE)

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
        page = body.get('page', 'unknown')

        item = {
            'id': str(uuid.uuid4()),
            'page': page,
            'timestamp': datetime.utcnow().isoformat()
        }

        table.put_item(Item=item)

        try:
            cloudwatch.put_metric_data(
                Namespace='Portfolio/Metrics',
                MetricData=[{
                    'MetricName': 'PageVisits',
                    'Dimensions': [{'Name': 'Page', 'Value': page}],
                    'Unit': 'Count',
                    'Value': 1
                }]
            )
        except Exception as e:
            print("CloudWatch metric publish failed:", str(e))

        return response(200, {'message': 'Visit logged!'})
    except Exception as e:
        print("Error:", str(e))
        traceback.print_exc()
        return response(500, {'error': 'Something went wrong' })
