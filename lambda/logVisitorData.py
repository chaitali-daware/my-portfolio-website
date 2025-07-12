import json
import boto3
import uuid
from datetime import datetime

# Initialize resources
dynamodb = boto3.resource('dynamodb')
cloudwatch = boto3.client('cloudwatch')
table = dynamodb.Table('VisitorLogs')

def lambda_handler(event, context):
    print("✅ Event received:", json.dumps(event))  # 👈 shows in CloudWatch Logs

    try:
        body = json.loads(event['body'])
        page = body.get('page', 'unknown')

        # Put item in DynamoDB
        table.put_item(Item={
            'VisitorID': str(uuid.uuid4()),
            'page': page,
            'timestamp': datetime.utcnow().isoformat()
        })

        # ✅ Publish custom metric to CloudWatch
        cloudwatch.put_metric_data(
            Namespace='Portfolio/Metrics',
            MetricData=[
                {
                    'MetricName': 'PageVisits',
                    'Dimensions': [
                        {'Name': 'Page', 'Value': page}
                    ],
                    'Unit': 'Count',
                    'Value': 1
                }
            ]
        )

        return {
            'statusCode': 200,
            'headers': {
                'Access-Control-Allow-Origin': '*',
                'Access-Control-Allow-Headers': '*'
            },
            'body': json.dumps({ 'message': 'Visit logged!' })
        }

    except Exception as e:
        print("❌ Error:", str(e))  # Logs error in CloudWatch
        return {
            'statusCode': 500,
            'headers': {
                'Access-Control-Allow-Origin': '*',

                'Access-Control-Allow-Headers': '*'
            },
            'body': json.dumps({ 'error': 'Something went wrong' })
        }


