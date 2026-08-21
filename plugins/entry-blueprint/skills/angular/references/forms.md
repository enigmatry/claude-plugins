# Angular Forms

Load this when the change builds or edits a form — controls, validation,
server-side errors, or form configuration.

## Controls and binding

- Typed `FormControl<T>` over untyped; it removes most casts. Initialize a static
  readonly control with `{ value: x, disabled: true }`.
- `patchValue()` against a typed model is the classic place Angular's types will
  not line up. Use the double cast `typescript` allows —
  `value as unknown as typeof this.form.value` — never `as any`.
- Bind with `formControlName` / `formArrayName` / `formGroupName`.

## Validation display

Validation display reads form state directly in the template — that is the
sanctioned exception to *no calls in a template* (`frontend-styling`), because
classic form state is not a signal:
`@if (form.controls.field.hasError('required')) { <mat-error>…</mat-error> }`.

## Server-side validation

Server-side validation errors are pushed back onto the form, not shown as a
toast — use the project's `setServerSideValidationErrors`-style helper and its
form-errors component.

## Organization

- Custom validators live in one shared location, not beside each feature.
- Form configuration (Formly, codegen) belongs in the configuration, not in the
  component.

## Signal Forms

**Signal Forms** (`@angular/forms/signals`) make value and state signals
(`form.email().value()`, `.errors()`, `.pending()`), removing the classic-forms
getter exception described in the main skill. They landed as *experimental* in
Angular 21 — **check your Angular version and the release notes before
migrating a form onto them.**
