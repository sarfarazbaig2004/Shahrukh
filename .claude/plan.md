# Plan: Fix Quotation Bug in Inquiry → Convert to Quotation Flow

## Current State

The sales quotation module already has:
- A single "GST (%)" input per line item.
- An internal `_isInterState` boolean derived from comparing `companyState` and `customerState`.
- Automatic tax splitting: when inter-state, the full GST goes to `igstPercent`; otherwise it is split 50/50 into `cgstPercent` / `sgstPercent`.
- Totals that are already recalculated per line item (`cgstAmount`, `sgstAmount`, `igstAmount`, `taxAmount`).
- A PDF financial summary that switches rows based on `isInterState`.

What is missing:
- A visible GST **type selector** at the quotation level (`CGST + SGST` vs `IGST`).
- Separate, editable CGST / SGST / IGST percentage fields.
- Persistence of the selected GST type independent of the auto-derived interstate flag.
- Backward compatibility for older records.
- Designation override so Sarfaraz Baig renders as **C.E.O** in quotation output.

## Root Cause of the Missing GST Options

The form treats GST as a single percentage and relies solely on the interstate address comparison to decide whether it is CGST+SGST or IGST. There is no persisted `gstType` field, no UI for the user to manually choose the tax mode, and no way to have different CGST/SGST rates. Old records therefore silently split or move the total GST at render/save time, which can lose the original intent.

## Implementation Strategy

### 1. Tax Mode Model

Introduce a persisted `gstType` enum/string with two values:
- `intra`  → CGST + SGST
- `inter`  → IGST

Keep the existing `_isInterState` boolean as the runtime rendering/saving flag. On create/restore we map:
- `gstType == 'inter'` OR legacy `isInterState == true`  → `_isInterState = true`
- `gstType == 'intra'` OR legacy `isInterState == false` → `_isInterState = false`

If both `gstType` and `isInterState` are absent, fallback to the address-based heuristic (`companyState != customerState`).

### 2. Screen Changes (quotation_screen_local.dart)

- Add a `gstType` state variable and a segmented/GST type selector near the customer address block.
- When `gstType` changes, re-run `_recalculateTaxes()` which will now distribute the stored per-item **total GST** into CGST/SGST or IGST based on the selected type.
- Keep `_isInterState` in sync with `gstType` so the existing totals card and PDF continue to work without redesign.
- In the totals card (around line 6661) show CGST/SGST or IGST rows as today; no UI redesign.
- In item dialogs (product add, scope item add/edit):
  - Replace the single `GST (%)` field with conditional fields:
    - Intra-state: CGST (%), SGST (%)
    - Inter-state: IGST (%)
  - Store the user-entered values directly on `cgstPercent`/`sgstPercent`/`igstPercent` and also store the **total GST** in `_itemExtras['baseGst']` so `_recalculateTaxes()` can re-split when the user toggles the GST type.
- Ensure `_recalculateTaxes()` never adds CGST+SGST and IGST together; it will zero the inactive pair.

### 3. Save / Update / Preview Mapping

Add to all three map builders (save, sales-order payload, preview):
- `'gstType': _isInterState ? 'inter' : 'intra'`
- Keep `'isInterState': _isInterState` for backward compatibility.
- Ensure `totalCgst`, `totalSgst`, `totalIgst` remain correct and zero-padded for the inactive tax.

### 4. Restore / Edit Backward Compatibility

In `_hydrateExistingQuotation`:
- Read `gstType` first.
- If absent, infer from `isInterState`.
- If both absent, infer from `companyState` vs `customerState`.
- Read legacy `gst`, `gstRate`, `taxRate` into `baseGst` and re-split.
- For old line items that already contain `cgst`/`sgst`/`igst` or `cgstPercent`/`sgstPercent`/`igstPercent`, use them directly (no silent modification).
- Only re-split if the active/inactive tax groups are inconsistent (e.g. CGST+SGST and IGST all non-zero) and only when the user changes the GST type.

### 5. PDF / Preview Changes (quotation_pdf_generator.dart)

- The PDF already uses `isInterState` to choose CGST+SGST or IGST rows, so minimal change is needed.
- Add an optional override in `_buildSignature`: when `signatureName` matches **Sarfaraz Baig** and `signatureDesignation` equals **Director**, render it as **C.E.O**. This is applied only at PDF/preview output time and does not rewrite saved documents.
- Apply the same override logic in the quotation form preview screen and in the signatory text field initialization so the on-screen value also shows C.E.O.

### 6. Designation Fix Scope

- Apply the Sarfaraz-Baig → C.E.O override only in quotation-related output paths:
  - `quotation_pdf_generator.dart` signature block
  - `quotation_screen_local.dart` signatory name/designation fields and any preview/export blocks
- Do **not** change global user/company management screens or the `Director` option list.
- If a company-level signatory setting already provides a designation, read it first; the override is a safe fallback only when the resolved value is `Director` for Sarfaraz Baig.

### 7. Rounding / Calculation Safety

- All model getters already use raw doubles; final formatting uses `toStringAsFixed(2)` / `NumberFormat.currency`.
- Keep `_cachedGrandTotal` = taxable + active taxes (no double taxation because inactive taxes are zero).
- Keep `_cachedFinalTotal = _cachedGrandTotal.roundToDouble()`.
- Test target cases:
  - CGST 9% + SGST 9% on ₹1,00,000 → CGST ₹9,000 + SGST ₹9,000 → total ₹1,18,000.
  - IGST 18% on ₹1,00,000 → IGST ₹18,000 → total ₹1,18,000.

## Files to Modify

1. `lib/modules/sales/quotations/quotation_screen_local.dart` — GST type selector, item dialogs, restore/save mapping, totals card sync.
2. `lib/modules/sales/quotations/quotation_pdf_generator.dart` — signature designation override for Sarfaraz Baig; ensure tax rows use `isInterState` correctly.

## Files to Inspect (read-only, no changes unless required)

- `lib/modules/purchase/purchase_quotations/quotation_screen_local.dart`
- `lib/modules/purchase/purchase_quotations/quotation_pdf_generator.dart`
- `lib/modules/service/service_quotations/create_service_quotation_screen.dart`
- `lib/modules/service/service_quotations/service_quotation_pdf_generator.dart`

The user explicitly limited this fix to the Inquiry → Convert to Quotation flow, so purchase/service quotation logic will not be touched unless the same bug blocks validation.

## Validation Steps

1. `dart format lib/modules/sales/quotations/quotation_screen_local.dart lib/modules/sales/quotations/quotation_pdf_generator.dart`
2. `flutter analyze --no-pub`
3. `flutter build web --no-pub --release`

## Risks & Mitigations

- **Risk:** Large file `quotation_screen_local.dart` may have merge conflicts with the ongoing modular refactor.  
  **Mitigation:** Make minimal, localized edits; avoid moving widgets or helpers.
- **Risk:** Backward compatibility for records with both CGST+SGST and IGST populated.  
  **Mitigation:** Treat the selected `gstType`/`isInterState` as the source of truth; zero the inactive pair only during recalculation triggered by the user, not on every load.
- **Risk:** Changing Sarfaraz Baig designation only in quotation output.  
  **Mitigation:** Apply override in a dedicated helper used only by PDF/preview/export paths, never in user-management screens.

## Reporting

At the end I will report:
- root cause of the missing GST options
- exact files modified
- GST fields added or reused
- calculation logic changed
- Firestore compatibility handling
- PDF changes
- exact location where Director was changed to C.E.O
- test calculations
- analyze result
- build result
- known limitations
