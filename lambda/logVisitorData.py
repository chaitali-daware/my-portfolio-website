import json  # For parsing and returning JSON data
import boto3  # AWS SDK for Python
import uuid  # To generate unique IDs
from datetime import datetime  # To get current UTC timestamp
import os  # To access environment variables

# Initialize DynamoDB resource and CloudWatch client
dynamodb = boto3.resource('dynamodb')
cloudwatch = boto3.client('cloudwatch')

# Get DynamoDB table name from environment variable, default to "VisitorLogs"
VISITOR_TABLE = os.environ.get("VISITOR_TABLE", "VisitorLogs")
table = dynamodb.Table(VISITOR_TABLE)

def lambda_handler(event, context):
    # Log the incoming event for debugging purposes
    print(" Event received:", json.dumps(event))

    try:
        # Parse the JSON body of the incoming HTTP request
        body = json.loads(event.get('body', '{}'))
        # Extract the 'page' field, default to 'unknown' if not provided
        page = body.get('page', 'unknown')

        # Create a new item to store in DynamoDB
        item = {
            'id': str(uuid.uuid4()),  # Unique ID for each visit
            'page': page,  # The page visited
            'timestamp': datetime.utcnow().isoformat()  # Current UTC timestamp
        }

        # Save the visit log to DynamoDB
        table.put_item(Item=item)

        # Publish metrics to CloudWatch for analytics
        cloudwatch.put_metric_data(
            Namespace='Portfolio/Metrics',  # Custom namespace for portfolio metrics
            MetricData=[
                {
                    'MetricName': 'PageVisits',  # Metric name for page visits
                    'Dimensions': [{'Name': 'Page', 'Value': page}],  # Track visits per page
                    'Unit': 'Count',  # Each visit counts as 1
                    'Value': 1
                }
            ]
        )

        # Return a successful response
        return {
            'statusCode': 200,
            'headers': {
                'Access-Control-Allow-Origin':'*',  # Enable CORS for frontend
                'Access-Control-Allow-Headers':'*'
            },
            'body': json.dumps({'message': 'Visit logged!'})
        }

    except Exception as e:
        # Log any errors for debugging
        print(" Error:", str(e))
        # Return an internal server error response
        return {
            'statusCode': 500,
            'headers': {
                'Access-Control-Allow-Origin':'*',
                'Access-Control-Allow-Headers':'*'
            },
            'body': json.dumps({'error': 'Something went wrong' })
        }
