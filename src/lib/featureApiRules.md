# API Filter Rules

This document describes how to use the filtering system for APIs that use the `FeatureApi` query builder.

The filtering system converts URL query parameters into **Prisma queries** automatically.

---

# 1. Basic Structure

All filters are passed as **query parameters** in the request URL.

Example:

```
GET /users?role_id=2&is_active=true
```

Generated Prisma query:

```ts
where: {
  role_id: 2,
  is_active: true
}
```

---

# 2. Direct Field Filtering

Use direct query parameters for fields that belong to the main model.

```
?field=value
```

Example:

```
/users?role_id=2
/users?is_active=true
/users?gender=MALE
/users?login_type=GOOGLE
```

Generated Prisma query:

```ts
where: {
  role_id: 2,
  is_active: true
}
```

---

# 3. Operators

Operators are used to apply conditions on fields.

Syntax:

```
?field[operator]=value
```

Supported operators:

| Operator   | Description           |
| ---------- | --------------------- |
| equals     | Equal                 |
| not        | Not equal             |
| gt         | Greater than          |
| gte        | Greater than or equal |
| lt         | Less than             |
| lte        | Less than or equal    |
| contains   | Text contains         |
| startsWith | Text starts with      |
| endsWith   | Text ends with        |
| in         | Value inside list     |
| notIn      | Value not inside list |

Example:

```
/users?created_at[gte]=2024-01-01
/users?created_at[lte]=2024-12-31
/users?full_name[contains]=ahmed
/users?role_id[in]=[1,2,3]
```

Generated Prisma query:

```ts
where: {
  created_at: {
    gte: new Date("2024-01-01"),
    lte: new Date("2024-12-31")
  }
}
```

---

# 4. Relation Filtering

To filter using related models, use nested query parameters.

Syntax:

```
?relation[field]=value
```

Example:

```
/users?courier[vehicle_type]=bike
```

Generated Prisma query:

```ts
where: {
  courier: {
    vehicle_type: "bike"
  }
}
```

---

# 5. Nested Relation Filtering

Relations can be nested multiple levels.

Example:

```
User → courier → selectedAreas → area_id
```

Query:

```
/users?courier[selectedAreas][some][area_id]=2
```

Generated Prisma query:

```ts
where: {
  courier: {
    selectedAreas: {
      some: {
        area_id: 2
      }
    }
  }
}
```

---

# 6. Relation List Operators

For relations that return arrays, Prisma requires one of these operators:

| Operator | Meaning                             |
| -------- | ----------------------------------- |
| some     | At least one related record matches |
| every    | All related records match           |
| none     | No related record matches           |

Examples:

Courier serves area 2:

```
/users?courier[selectedAreas][some][area_id]=2
```

Courier serves only area 2:

```
/users?courier[selectedAreas][every][area_id]=2
```

Courier does NOT serve area 2:

```
/users?courier[selectedAreas][none][area_id]=2
```

---

# 7. Date Range Filtering

Use `gte` and `lte` for date ranges.

Example:

```
/users?created_at[gte]=2024-01-01&created_at[lte]=2024-01-31
```

Generated Prisma query:

```ts
created_at: {
  gte: new Date("2024-01-01"),
  lte: new Date("2024-01-31")
}
```

---

# 8. Sorting

Sorting is done using the `sort` parameter.

Ascending:

```
/users?sort=created_at
```

Descending:

```
/users?sort=-created_at
```

Multiple sorting fields:

```
/users?sort=-created_at,full_name
```

---

# 9. Pagination

Pagination uses `limit` and `skip`.

Example:

```
/users?limit=10&skip=20
```

Generated Prisma query:

```ts
take: 10,
skip: 20
```

---

# 10. Keyword Search

Search across multiple fields using `keyword`.

Example:

```
/users?keyword=ahmed&items=full_name,email,phone
```

Generated Prisma query:

```ts
OR: [
  { full_name: { contains: "ahmed" } },
  { email: { contains: "ahmed" } },
  { phone: { contains: "ahmed" } }
]
```

---

# 11. Selecting Fields

Use `fields` to return only specific columns.

Example:

```
/users?fields=id,full_name,phone
```

Generated Prisma query:

```ts
select: {
  id: true,
  full_name: true,
  phone: true
}
```

---

# 12. Including Relations

Use `includes` to return related models.

Example:

```
/users?includes=courier
```

Selecting fields inside relations:

```
/users?includes=courier=id-vehicle_type
```

Generated Prisma query:

```ts
include: {
  courier: {
    select: {
      id: true,
      vehicle_type: true
    }
  }
}
```

---

# 13. Important Rules

1. Do not repeat query parameters.
2. Use operators for conditional filtering.
3. Use nested relations carefully.
4. Avoid very deep nesting unless necessary.
5. Always use pagination for list endpoints.

---

# 14. Example Complete Request

```
/users?
limit=10
&skip=0
&sort=-created_at
&fields=id,full_name,phone
&includes=courier=vehicle_type-vehicle_plate
&role_id=2
&created_at[gte]=2024-01-01
&created_at[lte]=2024-03-01
&courier[vehicle_type]=bike
&courier[selectedAreas][some][area_id]=2
```

This query will:

* paginate users
* sort by newest users
* return selected fields
* include courier information
* filter by role
* filter by date range
* filter couriers by vehicle type
* filter couriers serving a specific area

---
