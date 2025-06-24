import json

def lambda_handler(event, context):
    # Check if event is from SQS
    if 'Records' in event and event['Records'][0].get('eventSource') == 'aws:sqs':
        # Process SQS messages
        for record in event['Records']:
            body = record['body']
            print(f"Processing SQS message: {body}")
        return {"status": "SQS processed"}

    # Check if event is from EventBridge
    if 'source' in event:
        print(f"Received EventBridge event: {json.dumps(event)}")
        return {"status": "EventBridge processed"}

    return {"status": "Unknown event"}
