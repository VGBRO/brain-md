# Legacy → AgentScript Type Mapping

This table maps legacy `lightning:type` values from `genAiPlannerBundle` JSON schemas to their
AgentScript equivalents. Use this when designing variables (Skill 02) and generating action
definitions (Skill 04).

**CRITICAL RULE**: Every parameter in the legacy schema has a `lightning:type` value. That value
maps **directly** to the `complex_data_type_name` in AgentScript. Do NOT guess or default to
`lightning__objectType` — use the EXACT `lightning:type` from the legacy schema.

## Non-List Parameters

| Legacy `lightning:type` | AgentScript base type | `complex_data_type_name` |
|---|---|---|
| `lightning__textType` | `string` | — (not needed) |
| `lightning__recordIdType` | `object` | `lightning__recordIdType` |
| `lightning__recordInfoType` | `object` | `lightning__recordInfoType` |
| `lightning__richTextType` | `object` | `lightning__richTextType` |
| `lightning__emailType` | `object` | `lightning__emailType` |
| `lightning__booleanType` | `object` | `lightning__booleanType` |
| `lightning__integerType` | `object` | `lightning__integerType` |
| `lightning__doubleType` | `object` | `lightning__doubleType` |
| `lightning__dateType` | `object` | `lightning__dateType` |
| `lightning__dateTimeType` | `object` | `lightning__dateTimeType` |
| `lightning__dateTimeStringType` | `object` | `lightning__dateTimeStringType` |
| `lightning__currencyType` | `object` | `lightning__currencyType` |
| `lightning__objectType` | `object` | `lightning__objectType` |
| `@apexClassType/<ns>__<Class>` | `object` | `@apexClassType/<ns>__<Class>` (exact value) |

**Only `lightning__textType` maps to `string`.** Every other `lightning:type` maps to `object`
with `complex_data_type_name` set to the exact `lightning:type` value.

## List Parameters

When the legacy parameter has `"lightning:type": "lightning__listType"` with an `items` field:

1. **AgentScript base type**: `list[object]` (always `object` for items, unless items are
   `lightning__textType` → then `list[string]`)
2. **`complex_data_type_name`**: Use the ITEMS' `lightning:type` — NOT `lightning__listType`
   and NOT `lightning__objectType`

**Examples:**

| Legacy items `lightning:type` | AgentScript | `complex_data_type_name` |
|---|---|---|
| `lightning__recordInfoType` | `list[object]` | `lightning__recordInfoType` |
| `lightning__recordIdType` | `list[object]` | `lightning__recordIdType` |
| `lightning__textType` | `list[string]` | `lightning__textType` |
| `@apexClassType/c__MyClass` | `list[object]` | `@apexClassType/c__MyClass` |

**Legacy schema → AgentScript examples:**

```json
// Legacy: list of record IDs
"additionalRecordIds": {
  "lightning:type": "lightning__listType",
  "items": { "lightning:type": "lightning__recordIdType" }
}
```
```agentscript
# AgentScript:
additionalRecordIds: list[object]
   complex_data_type_name: "lightning__recordIdType"
```

```json
// Legacy: list of records
"result": {
  "lightning:type": "lightning__listType",
  "items": { "lightning:type": "lightning__recordInfoType" }
}
```
```agentscript
# AgentScript:
result: list[object]
   complex_data_type_name: "lightning__recordInfoType"
```

## Applies to BOTH Inputs AND Outputs

`complex_data_type_name` is required on BOTH input and output parameters — not just outputs.
The legacy schema specifies `lightning:type` on every parameter regardless of direction.

## Variables

For `@variables` declarations (Skill 02), use the "AgentScript base type" column above.
Verify the mapped type is valid for the chosen modifier (`mutable` vs `linked`) using the
Type Support Matrix in `AGENT_SCRIPT_RULES.md`.
