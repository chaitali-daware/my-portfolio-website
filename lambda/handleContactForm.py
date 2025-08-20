import json  # For parsing and returning JSON data
import boto3  # AWS SDK for Python
import uuid  # To generate unique IDs
import datetime  # To get current timestamp
import os  # To get environment variables

# Initialize DynamoDB resource and CloudWatch client
dynamodb = boto3.resource('dynamodb')
cloudwatch = boto3.client('cloudwatch')

# Get DynamoDB table name from environment variable, default to "ContactFormSubmissions"
CONTACT_TABLE = os.environ.get("CONTACT_TABLE", "ContactFormSubmissions")
table = dynamodb.Table(CONTACT_TABLE)

def lambda_handler(event, context):
    # Log the incoming event for debugging
    print(" Event received:", json.dumps(event))

    try:
        # Parse the JSON body of the HTTP request
        body = json.loads(event.get('body', '{}'))

        # Extract form fields
        name = body.get('name')
        email = body.get('email')
        message = body.get('message')
        referral_code = body.get('referralCode', 'Direct')  # Default to 'Direct' if not provided

        # Validate required fields
        if not name or not email or not message:
            return {
                'statusCode': 400,  # Bad Request
                'headers': {
                    'Access-Control-Allow-Origin': '*',  # Enable CORS
                    'Access-Control-Allow-Headers': '*'
                },
                'body': json.dumps({'error': 'Missing required fields.'})
            }

        # Create a new item to store in DynamoDB
        item = {
            'id': str(uuid.uuid4()),  # Unique ID for the submission
            'name': name,
            'email': email,
            'message': message,
            'referralCode': referral_code,
            'timestamp': datetime.datetime.utcnow().isoformat()  # Current UTC timestamp
        }

        # Save the item to DynamoDB
        table.put_item(Item=item)

        # Publish metrics to CloudWatch
        cloudwatch.put_metric_data(
            Namespace='Portfolio/Metrics',  # Custom namespace for your portfolio
            MetricData=[
                {
                    'MetricName': 'ContactSubmissions',  # Metric for total submissions
                    'Dimensions': [{'Name': 'Page', 'Value': 'Contact'}],
                    'Unit': 'Count',
                    'Value': 1
                },
                {
                    'MetricName': 'ReferralHits',  # Metric for referral tracking
                    'Dimensions': [{'Name': 'Source', 'Value': referral_code}],
                    'Unit': 'Count',
                    'Value': 1
                }
            ]
        )

        # Return success response
        return {
            'statusCode': 200,
            'headers': {
                'Access-Control-Allow-Origin': '*',  # Enable CORS
                'Access-Control-Allow-Headers': '*'
            },
            'body': json.dumps({'message': 'Message sent successfully!'})
        }

    except Exception as e:
        # Log any errors for debugging
        print(" Error:", str(e))

        # Return internal server error response
        return {
            'statusCode': 500,
            'headers': {
                'Access-Control-Allow-Origin': '*',  # Enable CORS
                'Access-Control-Allow-Headers': '*'
            },
            'body': json.dumps({'error': 'Failed to submit form.'})
        }
