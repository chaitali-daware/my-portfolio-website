import json
import boto3
import uuid
import datetime

# Initialize AWS resources
dynamodb = boto3.resource('dynamodb')
cloudwatch = boto3.client('cloudwatch')
table = dynamodb.Table('ContactFormSubmissions')

def cors_headers():
    return {
        "Access-Control-Allow-Origin": "*",  # Change to your domain for security
        "Access-Control-Allow-Methods": "OPTIONS,POST",
        "Access-Control-Allow-Headers": "*"
    }

def lambda_handler(event, context):
    print(" Event received:", json.dumps(event))

    # Detect HTTP method safely
    method = (
        event.get("requestContext", {}).get("http", {}).get("method")
        or event.get("httpMethod")
    )

    # Handle CORS Preflight (OPTIONS)
    if method == "OPTIONS":
        return {
            "statusCode": 200,
            "headers": cors_headers(),
            "body": ""
        }

    try:
        # Parse JSON body safely
        try:
            data = json.loads(event.get('body') or "{}")
        except json.JSONDecodeError:
            return {
                "statusCode": 400,
                "headers": cors_headers(),
                "body": json.dumps({"error": "Invalid JSON"})
            }

        name = data.get('name')
        email = data.get('email')
        message = data.get('message')
        referral_code = data.get('referralCode', 'Direct')

        # Validate required fields
        if not name or not email or not message:
            return {
                "statusCode": 400,
                "headers": cors_headers(),
                "body": json.dumps({"error": "Missing required fields"})
            }

        # Build DynamoDB item
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

        # Publish metrics to CloudWatch
        cloudwatch.put_metric_data(
            Namespace='Portfolio/Metrics',
            MetricData=[
                {
                    'MetricName': 'ContactSubmissions',
                    'Dimensions': [{'Name': 'Page', 'Value': 'Contact'}],
                    'Unit': 'Count',
                    'Value': 1
                },
                {
                    'MetricName': 'ReferralHits',
                    'Dimensions': [{'Name': 'Source', 'Value': referral_code}],
                    'Unit': 'Count',
                    'Value': 1
                }
            ]
        )

        # Successful response
        return {
            'statusCode': 200,
            'headers': cors_headers(),
            'body': json.dumps({'message': 'Message sent successfully!'})
        }

    except Exception as e:
        print("Error:", str(e))
        return {
            'statusCode': 500,
            'headers': cors_headers(),
            'body': json.dumps({'error': 'Failed to submit form.'})
        }
