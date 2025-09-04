### Validation Errors
Found **7** validation errors (showing first 3)
#### Error 1 {#error-1}
**Location:** `/preferences/notifications`
**Message:** Additional properties are not allowed ('sms' was unexpected)
**Validation Rule:** `additionalProperties`
**Context:**
```json
{
  "actual": {
    "email": true,
    "push": false,
    "sms": true
  },
  "constraint": "constraint: additionalProperties",
  "expected": "constraint satisfied",
  "instance_path": "/preferences/notifications",
  "schema_path": "/properties/preferences/properties/notifications/additionalProperties"
}
```
**Suggestions:**
- Validation failed for 'additionalProperties' constraint
- Expected: "constraint: additionalProperties"
- Check the schema documentation for this constraint
- Verify your data matches the expected format
- Error details: Additional properties are not allowed ('sms' was unexpected)
#### Error 2 {#error-2}
**Location:** `/preferences/theme`
**Message:** "purple" is not one of "light", "dark" or "auto"
**Validation Rule:** `enum`
**Context:**
```json
{
  "actual": "purple",
  "constraint": [
    "light",
    "dark",
    "auto"
  ],
  "expected": "constraint satisfied",
  "instance_path": "/preferences/theme",
  "schema_path": "/properties/preferences/properties/theme/enum"
}
```
**Suggestions:**
- Value must be one of: \["light","dark","auto"\]
#### Error 3 {#error-3}
**Location:** `/settings/language`
**Message:** "invalid-lang-code" does not match "^\[a-z\]{2}(-\[A-Z\]{2})?$"
**Validation Rule:** `pattern`
**Context:**
```json
{
  "actual": "invalid-lang-code",
  "expected": "match pattern: \"^[a-z]{2}(-[A-Z]{2})?$\"",
  "instance_path": "/settings/language",
  "pattern": "^[a-z]{2}(-[A-Z]{2})?$",
  "schema_path": "/properties/settings/properties/language/pattern",
  "value": "invalid-lang-code"
}
```
**Suggestions:**
- String must match pattern: "^\[a-z\]{2}(-\[A-Z\]{2})?$"