# Area Boundary Validation

> **Audience:** Next.js web developers.
> All logic described here lives in the Flutter app — replicate the same behaviour on the web.

---

## Overview

When a customer picks a delivery or pickup location on the map, the app validates that the chosen pin actually falls inside the area they selected. This prevents orders being placed with mismatched or out-of-range coordinates.

Validation runs in **two places**:

| Where                                | When                                                    |
| ------------------------------------ | ------------------------------------------------------- |
| **Address form** (save address flow) | On submit, before saving a new address                  |
| **Create order sheet**               | When a saved address is selected for pickup or delivery |

---

## Step 1 — Fetch Areas & Their Boundaries

Before any validation can happen, the app loads all governorates and their child areas from the API. This is done once on app start / address form open.

```
GET /governorates?includes=areas&is_active=true&areas[is_active]=true
```

**Response shape (relevant fields):**

```json
{
  "governorates": [
    {
      "id": 1,
      "name": "Cairo",
      "name_ar": "القاهرة",
      "areas": [
        {
          "id": 12,
          "governorate_id": 1,
          "name": "Maadi",
          "name_ar": "المعادي",
          "boundaries": {
            "point1": "29.96,31.25",
            "point2": "29.98,31.27",
            "point3": "29.97,31.29"
          },
          "created_at": "...",
          "updated_at": "..."
        }
      ]
    }
  ],
  "totalCount": 5,
  "totalPages": 1
}
```

**`boundaries` format** — the API can return points in two formats, both must be supported:

| Format                | Example                          |
| --------------------- | -------------------------------- |
| String `"lat,lng"`    | `"29.96,31.25"`                  |
| Object `{ lat, lng }` | `{ "lat": 29.96, "lng": 31.25 }` |

Keys are named `point1`, `point2`, `point3`, … (arbitrary count, sorted alphabetically before use).

---

## Step 2 — Map Picker & Auto-centering

When the customer opens the map picker to pin a location, the map centers on:

1. Their previously saved lat/lng (if editing an address), **or**
2. The **centroid** of the selected area's boundary polygon (if no prior pin), **or**
3. Cairo fallback `(30.0444, 31.2357)`

**Centroid calculation:**

```
centroidLat = average of all boundary point latitudes
centroidLng = average of all boundary point longitudes
```

The map picker returns: `{ latitude, longitude, address, administrativeArea, governorate }`

`administrativeArea` comes from Google Geocoding's `administrative_area_level_2` component (district level).

---

## Step 3 — Three-step Address Validation

After the customer confirms their pin and submits the form, validation runs in order:

### Step 1 — Name check against the selected area

Compare the `administrativeArea` string returned by Google Maps against the selected area's `name` (EN) and `name_ar` (AR).

**Matching logic** (case-insensitive, spaces stripped):

```
normalize = (s) => s.toLowerCase().replaceAll(' ', '')

matchesAr = areaNameAr.contains(pickedNormalized) || pickedNormalized.contains(areaNameAr)
matchesEn = areaNameEn.contains(pickedNormalized) || pickedNormalized.contains(areaNameEn)

nameMatches = matchesAr || matchesEn
```

If `nameMatches = true` → **validation passes, skip steps 2 & 3.**

---

### Step 2 — Search all areas for a name match

If step 1 failed (name didn't match the selected area), search **all** areas across all governorates for a name match using the same logic.

- If a different area matches → update the selected area to that match, set `nameMatches = true`, **validation passes, skip step 3.**
- If no area matches → fall through to step 3.

---

### Step 3 — Boundary check

If both name checks failed, run a geometric point-in-polygon check.

**Source:** `lib/core/utils/area_boundry_validator.dart` — `AreaBoundaryValidator.isPointInArea()`

#### 2-point boundaries → Bounding box

If the area only has 2 boundary points, treat them as opposite corners of a rectangle:

```
minLat = min(p1.lat, p2.lat)
maxLat = max(p1.lat, p2.lat)
minLng = min(p1.lng, p2.lng)
maxLng = max(p1.lng, p2.lng)

isInside = lat >= minLat && lat <= maxLat && lng >= minLng && lng <= maxLng
```

#### 3+ points → Ray-casting algorithm

```
crossings = 0
for each edge (A → B) in the polygon (wrapping last → first):
  if the ray going right from (lat, lng) crosses this edge:
    crossings++

isInside = crossings is odd
```

Ray-crossing condition for edge A→B:

```
(A.lng <= lng < B.lng  OR  B.lng <= lng < A.lng)
AND
lat < (B.lat - A.lat) / (B.lng - A.lng) * (lng - A.lng) + A.lat
```

#### Special case — no boundaries defined

If the area's `boundaries` map is empty, the validator returns `true` (permissive — no restriction enforced).

---

## Step 3 — Outcomes

| Result                                       | Action                                                                                                            |
| -------------------------------------------- | ----------------------------------------------------------------------------------------------------------------- |
| Name matched (step 1 or 2)                   | ✅ Save address                                                                                                   |
| Pin inside boundaries (step 3)               | ✅ Save address                                                                                                   |
| Name mismatch **and** pin outside boundaries | ❌ Show error: _"Address is outside the selected area"_ + call `POST /addresses/unavailable` with the pin details |
| lat/lng unparseable                          | ⚠️ Skip validation, save anyway                                                                                   |
| Area not found in loaded data                | ⚠️ Skip validation, save anyway                                                                                   |

---

## Auto-detect Area from Pin (Address Form)

When the customer drops a pin **without** selecting an area first, the app tries to auto-detect the correct area by running `isPointInArea` against every area's boundaries and picking the first match:

```
matchedArea = allAreas.find(area => isPointInArea(lat, lng, area.boundaries))
```

If found, the area dropdown is pre-selected automatically.

---

## Validation in the Order Sheet

When a saved address is selected during order creation, a lighter check runs:

```dart
bool _isAddressInArea(Address address) {
  final area = findAreaById(address.areaId);
  if (area == null) return true;  // no area data → allow
  return AreaBoundaryValidator.isPointInArea(
    lat: address.lat,
    lng: address.lng,
    boundaries: area.boundaries,
  );
}
```

If this returns `false`, the address is marked as invalid and the customer cannot proceed with order creation using that address.

---

## Summary — What to Implement on the Web

| Task                | Detail                                                                                       |
| ------------------- | -------------------------------------------------------------------------------------------- |
| Fetch areas         | `GET /governorates?includes=areas&is_active=true&areas[is_active]=true` on page load         |
| Parse boundaries    | Support both `"lat,lng"` string and `{ lat, lng }` object formats; sort keys alphabetically  |
| Map centering       | Center on area centroid (avg lat/lng of boundary points) when no prior pin                   |
| Name validation     | Normalize + substring match against EN and AR area names (steps 1 & 2)                       |
| Boundary validation | Bounding box for 2 points; ray-casting for 3+ points (step 3)                                |
| Failure UX          | Show error banner + call unavailable address endpoint                                        |
| Auto-detect         | On pin drop, scan all area boundaries to suggest the correct area                            |
| Order sheet         | Re-validate saved address coordinates against area boundary before allowing order submission |
