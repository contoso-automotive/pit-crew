# Implementation plan: Return 404, not 500, for an unknown VIN

## Goal

For `GET /recalls/{vin}`, return `404 Not Found` when a syntactically valid VIN has no vehicle record. Keep `400 Bad Request` for malformed VINs and `200 OK` for known VINs. An unknown VIN is an expected lookup miss, not an internal server error.

## Current behavior

`src/recalls/routes.ts` normalizes and validates the VIN, then calls `getVehicle`. In `src/recalls/lookup.ts`, `getVehicle` throws a generic `Error` when the VIN is not in the vehicle map. That error reaches the app-wide error handler in `src/app.ts`, which logs it and responds with `500`.

## Planned changes

1. **Represent a missing vehicle explicitly.** Use a narrow, recognizable not-found result from the lookup layer (for example, a dedicated `VehicleNotFoundError`) rather than relying on an error-message string or treating every lookup error as a client error.
2. **Map that result at the recalls route boundary.** After the existing VIN normalization and shape validation, translate only the known missing-vehicle result to `404` and return a small JSON error body. Re-throw other errors so they continue through the existing `500` handler and logging.
3. **Add focused route contract coverage** in `src/recalls/routes.test.ts` for an unknown but well-formed VIN, asserting `404` and the error response. Retain the existing known-VIN `200` and malformed-VIN `400` assertions.

## Acceptance criteria

- A malformed VIN still returns `400`.
- A well-formed VIN present in the synthetic vehicle data still returns `200` with the existing response shape.
- A well-formed VIN absent from the vehicle data returns `404`, not `500`.
- Only the expected vehicle-not-found condition is mapped to `404`; unexpected exceptions remain `500`.
- The change adds no dependencies, changes no synthetic data, and leaves global error handling and unrelated routes unchanged.

## Verification

- Run the focused recalls route tests (`npx vitest run src/recalls/routes.test.ts`).
- Run `npm run lint`, `npm run typecheck`, and `npm test` to check the full repository suite.
- Use a well-formed, absent VIN for the not-found test case; do not make behavior depend on a VIN failing its check digit, since VIN validation here checks shape and the repository's synthetic-data rule requires data VINs to fail the real check digit.

## Risks and mitigations

- **Accidentally converting internal failures to 404:** Catch or inspect only the dedicated not-found condition; propagate all other exceptions.
- **Confusing malformed and unknown input:** Keep format validation before lookup and test both cases independently.
- **Changing the API contract unnecessarily:** Preserve the existing successful response and limit the new response shape to the not-found case.
