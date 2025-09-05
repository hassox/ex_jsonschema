## Validation Errors
Found **7** validation errors.
### Error 1 {#error-1}
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
### Error 2 {#error-2}
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
### Error 3 {#error-3}
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
### Error 4 {#error-4}
**Location:** `/user/age`
**Message:** 15 is less than the minimum of 18
**Validation Rule:** `minimum`
**Context:**
```json
{
  "actual": 15,
  "actual_value": 15,
  "expected": "value >= 18",
  "instance_path": "/user/age",
  "minimum_value": 18,
  "schema_path": "/properties/user/properties/age/minimum"
}
```
**Suggestions:**
- Value must be >= 18
### Error 5 {#error-5}
**Location:** `/user/name`
**Message:** "X" is shorter than 2 characters
**Validation Rule:** `minLength`
**Context:**
```json
{
  "actual": "length: 1",
  "actual_length": 1,
  "expected": "length >= 2",
  "instance_path": "/user/name",
  "minimum_length": 2,
  "schema_path": "/properties/user/properties/name/minLength"
}
```
**Suggestions:**
- String must be at least 2 characters
### Error 6 {#error-6}
**Location:** `/user/roles/1`
**Message:** "invalid-role" is not one of "admin", "user" or "moderator"
**Validation Rule:** `enum`
**Context:**
```json
{
  "actual": "invalid-role",
  "constraint": [
    "admin",
    "user",
    "moderator"
  ],
  "expected": "constraint satisfied",
  "instance_path": "/user/roles/1",
  "schema_path": "/properties/user/properties/roles/items/enum"
}
```
**Suggestions:**
- Value must be one of: \["admin","user","moderator"\]
### Error 7 {#error-7}
**Location:** `/user/roles`
**Message:** \["admin","invalid-role","admin"\] has non-unique elements
**Validation Rule:** `uniqueItems`
**Context:**
```json
{
  "actual": [
    "admin",
    "invalid-role",
    "admin"
  ],
  "constraint": "constraint: uniqueItems",
  "expected": "constraint satisfied",
  "instance_path": "/user/roles",
  "schema_path": "/properties/user/properties/roles/uniqueItems"
}
```
**Suggestions:**
- Array items must be unique