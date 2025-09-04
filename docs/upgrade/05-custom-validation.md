# Surface 5: Custom Validation

## Current State
- No custom keyword support
- Limited to built-in JSON Schema keywords
- No extensibility for domain-specific validation

## Target Capabilities (from Rust crate)
- Custom keyword implementation via `Keyword` trait
- Custom format validators
- Plugin architecture for validation extensions
- Runtime registration of custom validators
- Context-aware validation logic

## Proposed Elixir API Design

### Custom Keywords
```elixir
defmodule ExJsonschema.CustomKeyword do
  @type validation_result :: :ok | {:error, String.t()}
  @type context :: %{
    instance: term(),
    schema: map(),
    instance_path: String.t(),
    schema_path: String.t()
  }
  
  @callback validate(context()) :: validation_result()
  @callback keyword() :: String.t()
end

defmodule MyApp.Keywords.BusinessRule do
  @behaviour ExJsonschema.CustomKeyword
  
  @impl true
  def keyword, do: "businessRule"
  
  @impl true  
  def validate(context) do
    rule = context.schema["businessRule"]
    instance = context.instance
    
    case apply_business_rule(rule, instance) do
      true -> :ok
      false -> {:error, "Business rule '#{rule}' validation failed"}
    end
  end
end
```

### Custom Formats
```elixir
defmodule ExJsonschema.CustomFormat do
  @type validation_result :: boolean()
  
  @callback validate(String.t()) :: validation_result()
  @callback format() :: String.t()
end

defmodule MyApp.Formats.CreditCard do
  @behaviour ExJsonschema.CustomFormat
  
  @impl true
  def format, do: "credit-card"
  
  @impl true
  def validate(value) do
    # Luhn algorithm implementation
    luhn_valid?(value) and String.length(value) in 13..19
  end
end

defmodule MyApp.Formats.BusinessId do
  @behaviour ExJsonschema.CustomFormat
  
  @impl true  
  def format, do: "business-id"
  
  @impl true
  def validate(value) do
    Regex.match?(~r/^[A-Z]{2}-\d{6}-[A-Z]{3}$/, value)
  end
end
```

### Registration and Usage
```elixir
# Register custom validators
ExJsonschema.register_keyword(MyApp.Keywords.BusinessRule)
ExJsonschema.register_format(MyApp.Formats.CreditCard) 
ExJsonschema.register_format(MyApp.Formats.BusinessId)

# Use in schema compilation
schema = ~s({
  "type": "object",
  "properties": {
    "creditCard": {"type": "string", "format": "credit-card"},
    "businessId": {"type": "string", "format": "business-id"},
    "account": {"businessRule": "active-account-required"}
  }
})

{:ok, validator} = ExJsonschema.compile(schema, 
  custom_keywords: [MyApp.Keywords.BusinessRule],
  custom_formats: [MyApp.Formats.CreditCard, MyApp.Formats.BusinessId]
)
```

### Registry-based Management
```elixir
defmodule MyApp.ValidationRegistry do
  use ExJsonschema.Registry
  
  def setup do
    # Register all custom validators for the application
    register_keywords([
      MyApp.Keywords.BusinessRule,
      MyApp.Keywords.AgeVerification,
      MyApp.Keywords.GeographicRestriction
    ])
    
    register_formats([
      MyApp.Formats.CreditCard,
      MyApp.Formats.BusinessId, 
      MyApp.Formats.PhoneNumber
    ])
  end
  
  def compile_with_customs(schema, opts \\ []) do
    ExJsonschema.compile(schema, [
      custom_keywords: get_keywords(),
      custom_formats: get_formats()
    ] ++ opts)
  end
end
```

### Context-Aware Validation
```elixir
defmodule MyApp.Keywords.ConditionalRequired do
  @behaviour ExJsonschema.CustomKeyword
  
  @impl true
  def keyword, do: "conditionalRequired" 
  
  @impl true
  def validate(context) do
    conditions = context.schema["conditionalRequired"]
    instance = context.instance
    
    Enum.reduce_while(conditions, :ok, fn {condition, required_fields}, _acc ->
      if condition_matches?(condition, instance) do
        missing = required_fields -- Map.keys(instance)
        if missing == [] do
          {:cont, :ok}
        else
          {:halt, {:error, "Missing required fields: #{Enum.join(missing, ", ")}"}}
        end
      else
        {:cont, :ok}
      end
    end)
  end
end
```

## Implementation Plan

### Phase 1: Custom Format Support
1. Design format registration system
2. Implement built-in format validators as examples
3. Create format validation infrastructure in Rust NIF
4. Add format registration APIs

### Phase 2: Custom Keywords Infrastructure  
1. Design keyword registration system
2. Create callback infrastructure for custom validation
3. Implement context passing between Rust and Elixir
4. Add keyword registration APIs

### Phase 3: Registry and Management
1. Build validation registry system
2. Implement runtime registration and deregistration
3. Add validation lifecycle management
4. Create testing utilities for custom validators

### Phase 4: Advanced Features
1. Add validation composition and chaining
2. Implement validation caching for expensive custom rules
3. Add validation metrics and monitoring
4. Create development tools and debugging support

## Rust Integration Points
- Implement custom `Keyword` trait in Rust that calls Elixir
- Use Rust format validation hooks with Elixir callbacks
- Handle context serialization between Rust and Elixir
- Manage validator lifecycle and memory safety

## API Examples

### E-commerce Validation
```elixir
defmodule Ecommerce.Keywords.Inventory do
  @behaviour ExJsonschema.CustomKeyword
  
  @impl true
  def keyword, do: "inventoryCheck"
  
  @impl true
  def validate(context) do
    product_id = context.instance["productId"]
    quantity = context.instance["quantity"]
    
    case InventoryService.check_availability(product_id, quantity) do
      {:ok, available} when available >= quantity -> :ok
      {:ok, available} -> {:error, "Only #{available} items available, requested #{quantity}"}
      {:error, :not_found} -> {:error, "Product #{product_id} not found"}
    end
  end
end

# Schema usage  
order_schema = ~s({
  "type": "object",
  "properties": {
    "items": {
      "type": "array", 
      "items": {
        "type": "object",
        "inventoryCheck": true,
        "properties": {
          "productId": {"type": "string"},
          "quantity": {"type": "number", "minimum": 1}
        }
      }
    }
  }
})
```

### Geographic Restrictions
```elixir
defmodule Compliance.Keywords.GeoRestriction do
  @behaviour ExJsonschema.CustomKeyword
  
  @impl true
  def keyword, do: "geoRestriction"
  
  @impl true
  def validate(context) do
    restrictions = context.schema["geoRestriction"]
    user_country = context.instance["country"]
    
    cond do
      user_country in restrictions["blockedCountries"] ->
        {:error, "Service not available in #{user_country}"}
        
      restrictions["allowedCountries"] && user_country not in restrictions["allowedCountries"] ->
        {:error, "Service only available in: #{Enum.join(restrictions["allowedCountries"], ", ")}"}
        
      true -> :ok
    end
  end
end
```

### Custom Format Examples
```elixir
defmodule MyApp.Formats.ISBN do
  @behaviour ExJsonschema.CustomFormat
  
  @impl true
  def format, do: "isbn"
  
  @impl true
  def validate(value) do
    # ISBN-10 or ISBN-13 validation
    cleaned = String.replace(value, ~r/[-\s]/, "")
    
    case String.length(cleaned) do
      10 -> validate_isbn10(cleaned)
      13 -> validate_isbn13(cleaned)
      _ -> false
    end
  end
end

defmodule MyApp.Formats.VIN do
  @behaviour ExJsonschema.CustomFormat
  
  @impl true 
  def format, do: "vin"
  
  @impl true
  def validate(value) do
    String.length(value) == 17 and
    Regex.match?(~r/^[A-HJ-NPR-Z0-9]+$/, value) and
    valid_check_digit?(value)
  end
end
```

## Testing Custom Validators
```elixir
defmodule MyApp.CustomValidatorTest do
  use ExUnit.Case
  
  test "credit card format validation" do
    assert MyApp.Formats.CreditCard.validate("4111111111111111") == true
    assert MyApp.Formats.CreditCard.validate("1234") == false
  end
  
  test "business rule keyword validation" do
    context = %{
      instance: %{"status" => "active", "balance" => 100},
      schema: %{"businessRule" => "positive-balance"},
      instance_path: "/account",
      schema_path: "/properties/account/businessRule"
    }
    
    assert MyApp.Keywords.BusinessRule.validate(context) == :ok
  end
  
  test "custom validation integration" do
    schema = ~s({
      "type": "object", 
      "properties": {
        "card": {"type": "string", "format": "credit-card"}
      }
    })
    
    {:ok, validator} = ExJsonschema.compile(schema, 
      custom_formats: [MyApp.Formats.CreditCard]
    )
    
    assert ExJsonschema.valid?(validator, ~s({"card": "4111111111111111"})) == true
    assert ExJsonschema.valid?(validator, ~s({"card": "invalid"})) == false
  end
end
```

## Performance Considerations
- Cache validation results for expensive custom logic
- Minimize Rust ↔ Elixir boundary crossings
- Use lazy evaluation for conditional validations
- Profile custom validator performance impact

## Security Considerations  
- Validate custom validator implementations
- Sandbox custom validation code if needed
- Limit resource usage in custom validators
- Audit custom validator permissions and capabilities

## Backward Compatibility
- Custom validation is additive and opt-in
- No impact on existing validation behavior
- Clear separation between built-in and custom validation
- Easy migration path for adding custom validation