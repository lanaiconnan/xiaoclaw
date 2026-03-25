# WhatsApp Channel Integration

## Overview

XiaoClaw supports WhatsApp Business API for sending and receiving messages.

## Setup

### 1. Create WhatsApp Business Account

1. Visit [WhatsApp Business Platform](https://www.whatsapp.com/business/)
2. Create a business account
3. Get your Phone Number ID and API Key

### 2. Configure Environment

Add to `.env`:

```bash
WHATSAPP_API_KEY=your_api_key
WHATSAPP_PHONE_NUMBER_ID=your_phone_id
WHATSAPP_WEBHOOK_TOKEN=your_webhook_token
WHATSAPP_ENABLED=true
```

### 3. Setup Webhook

Configure webhook URL in WhatsApp Business settings:

```
https://your-domain.com/webhooks/whatsapp
```

Verify token: Use the value from `WHATSAPP_WEBHOOK_TOKEN`

## Features

### Text Messages

```moonbit
channel.send_text(phone_number, "Hello from XiaoClaw!")
```

### Image Messages

```moonbit
channel.send_image(
  phone_number,
  "https://example.com/image.jpg",
  Some("Image caption")
)
```

### Button Messages

```moonbit
let buttons = [
  WhatsAppButton::quick_reply("1", "Yes"),
  WhatsAppButton::quick_reply("2", "No"),
]
channel.send_buttons(phone_number, "Do you agree?", buttons)
```

### Template Messages

```moonbit
let components = [
  { "type": "body", "parameters": [{ "type": "text", "text": "Hello" }] }
]
channel.send_template(phone_number, "hello_world", components)
```

## Webhook Events

### Message Received

```json
{
  "object": "whatsapp_business_account",
  "entry": [{
    "changes": [{
      "value": {
        "messages": [{
          "from": "1234567890",
          "id": "wamid.xxx",
          "type": "text",
          "text": { "body": "Hello" }
        }]
      }
    }]
  }]
}
```

### Message Delivery

```json
{
  "object": "whatsapp_business_account",
  "entry": [{
    "changes": [{
      "value": {
        "statuses": [{
          "id": "wamid.xxx",
          "status": "delivered",
          "timestamp": "1234567890"
        }]
      }
    }]
  }]
}
```

## Message Types

| Type | Support |
|------|---------|
| Text | ✅ |
| Image | ✅ |
| Audio | ✅ |
| Video | ✅ |
| Document | ✅ |
| Location | ✅ |
| Sticker | ✅ |
| Template | ✅ |
| Interactive | ✅ |

## Rate Limits

- Standard: 1000 messages/day
- Business: Unlimited (with approval)

## Best Practices

1. **Always mark messages as read**
   ```moonbit
   channel.mark_read(message_id)
   ```

2. **Use templates for common messages**
   - Faster delivery
   - Better formatting
   - Pre-approved content

3. **Handle media efficiently**
   - Download and cache media
   - Respect file size limits

4. **Implement retry logic**
   - Network failures are common
   - Use exponential backoff

## Troubleshooting

### Webhook not receiving messages

- Check webhook URL is publicly accessible
- Verify webhook token matches
- Check firewall/security settings

### Messages not sending

- Verify API key is correct
- Check phone number format (include country code)
- Ensure recipient has opted in

### Rate limit errors

- Implement backoff strategy
- Batch messages when possible
- Request higher limits from WhatsApp

---

**WhatsApp Integration Guide** 📱
