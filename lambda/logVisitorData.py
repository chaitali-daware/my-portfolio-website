import json
import boto3
import uuid
from datetime import datetime

# Initialize AWS resources
dynamodb = boto3.resource('dynamodb')
cloudwatch = boto3.client('cloudwatch')
table = dynamodb.Table('VisitorLogs')

def cors_headers():
    return {
        "Access-Control-Allow-Origin": "*",  # Replace * with your domain for security
        "Access-Control-Allow-Methods": "OPTIONS,POST",
        "Access-Control-Allow-Headers": "*"
    }

def lambda_handler(event, context):
    print("Event received:", json.dumps(event))

    # Detect method safely (supports REST and HTTP APIs)
    method = event.get("requestContext", {}).get("http", {}).get("method") or event.get("httpMethod")

    # Handle CORS preflight
    if method == "OPTIONS":
        return {"statusCode": 200, "headers": cors_headers(), "body": ""}

    try:
        # Parse body safely
        try:
            body = json.loads(event.get("body") or "{}")
        except json.JSONDecodeError:
            return {
                "statusCode": 400,
                "headers": cors_headers(),
                "body": json.dumps({"error": "Invalid JSON body"})
            }

        page = body.get("page", "unknown")

        # Store visitor info in DynamoDB
        table.put_item(Item={
            "VisitorID": str(uuid.uuid4()),
            "page": page,
            "timestamp": datetime.utcnow().isoformat()
        })

        # Publish custom metric to CloudWatch
        cloudwatch.put_metric_data(
            Namespace="Portfolio/Metrics",
            MetricData=[
                {
                    "MetricName": "PageVisits",
                    "Dimensions": [{"Name": "Page", "Value": page}],
                    "Unit": "Count",
                    "Value": 1
                }
            ]
        )

        return {
            "statusCode": 200,
            "headers": cors_headers(),
            "body": json.dumps({"message": "Visit logged!"})
        }

    except Exception as e:
        print("Error:", str(e))
        return {
            "statusCode": 500,
            "headers": cors_headers(),
            "body": json.dumps({"error": "Something went wrong"})
        }
