# API Endpoints Required for URL Feature

This document specifies the backend API endpoints needed to support the URL sharing feature in the hamrah-ios app.

## Base URL
All endpoints are relative to the configured API base URL (e.g., `https://api.hamrah.app/api`)

## Authentication
All endpoints require authentication via `Authorization: Bearer <access_token>` header, except where noted.

## Endpoints

### 1. Submit URL for Processing

**POST** `/api/urls`

Submit a new URL for processing and storage.

#### Request Headers
- `Authorization: Bearer <access_token>`
- `Content-Type: application/json`
- App Attestation headers (handled by SecureAPIService)

#### Request Body
```json
{
  "url": "https://example.com/article",
  "client_id": "uuid-generated-by-client"
}
```

#### Response (201 Created)
```json
{
  "success": true,
  "id": "backend-generated-uuid",
  "url": "https://example.com/article",
  "title": null,
  "summary": null,
  "tags": [],
  "processingStatus": "pending",
  "createdAt": "2024-01-01T12:00:00Z"
}
```

#### Error Response (4xx/5xx)
```json
{
  "success": false,
  "error": "Invalid URL format"
}
```

### 2. Get URL Details

**GET** `/api/urls/{id}`

Get details for a specific URL by its backend ID.

#### Request Headers
- `Authorization: Bearer <access_token>`
- App Attestation headers

#### Response (200 OK)
```json
{
  "success": true,
  "id": "backend-uuid",
  "url": "https://example.com/article",
  "title": "Article Title",
  "summary": "Brief summary of the article content...",
  "tags": ["technology", "programming", "web"],
  "processingStatus": "completed",
  "createdAt": "2024-01-01T12:00:00Z",
  "updatedAt": "2024-01-01T12:05:00Z"
}
```

### 3. Get User's URLs

**GET** `/api/urls`

Get all URLs for the authenticated user with optional pagination and filtering.

#### Query Parameters
- `limit` (optional): Maximum number of URLs to return (default: 50)
- `offset` (optional): Number of URLs to skip for pagination (default: 0)
- `status` (optional): Filter by processing status (`pending`, `processing`, `completed`, `failed`)

#### Request Headers
- `Authorization: Bearer <access_token>`
- App Attestation headers

#### Response (200 OK)
```json
{
  "success": true,
  "urls": [
    {
      "id": "backend-uuid-1",
      "url": "https://example.com/article1",
      "title": "First Article",
      "summary": "Summary of first article...",
      "tags": ["tag1", "tag2"],
      "processingStatus": "completed",
      "createdAt": "2024-01-01T12:00:00Z",
      "updatedAt": "2024-01-01T12:05:00Z"
    },
    {
      "id": "backend-uuid-2", 
      "url": "https://example.com/article2",
      "title": null,
      "summary": null,
      "tags": [],
      "processingStatus": "pending",
      "createdAt": "2024-01-01T13:00:00Z",
      "updatedAt": "2024-01-01T13:00:00Z"
    }
  ],
  "pagination": {
    "total": 2,
    "limit": 50,
    "offset": 0,
    "hasMore": false
  }
}
```

### 4. Delete URL

**DELETE** `/api/urls/{id}`

Delete a URL and its associated data.

#### Request Headers
- `Authorization: Bearer <access_token>`
- App Attestation headers

#### Response (200 OK)
```json
{
  "success": true,
  "message": "URL deleted successfully"
}
```

#### Error Response (404 Not Found)
```json
{
  "success": false,
  "error": "URL not found"
}
```

## Processing Status Values

- `pending`: URL has been received but processing has not started
- `processing`: URL is currently being processed (extracting title, summary, tags)
- `completed`: Processing finished successfully, all data available
- `failed`: Processing failed, may include error details

## Implementation Notes

1. **Offline-First**: The iOS app saves URLs locally first, then syncs with the backend when online
2. **Idempotency**: Use the `client_id` to prevent duplicate submissions if the client retries
3. **Processing**: URLs are processed asynchronously on the backend. The app polls for updates on URLs with `pending` or `processing` status
4. **Security**: All requests must include App Attestation headers for verification
5. **Rate Limiting**: Consider implementing rate limiting on URL submissions to prevent abuse
6. **Content Extraction**: The backend should extract title, summary, and auto-generate relevant tags from the URL content
7. **Error Handling**: Provide clear error messages for invalid URLs, processing failures, etc.

## Database Schema Suggestions

The backend should store:
- `id`: Primary key (UUID)
- `user_id`: Foreign key to user
- `url`: The original URL (text/varchar, indexed)
- `title`: Extracted title (text, nullable)
- `summary`: Extracted summary (text, nullable) 
- `tags`: Array of tags (JSON array or separate table)
- `processing_status`: Enum (pending, processing, completed, failed)
- `processing_error`: Error message if processing failed (text, nullable)
- `client_id`: Client-provided UUID for idempotency (UUID, nullable)
- `created_at`: Timestamp when URL was first submitted
- `updated_at`: Timestamp when URL data was last modified
- `metadata`: Additional extracted metadata (JSON, nullable)