# Registration Processes

<cite>
**Referenced Files in This Document**
- [auth_controller.dart](file://lib/features/auth/controllers/auth_controller.dart)
- [deliveryman_registration_controller.dart](file://lib/features/auth/controllers/deliveryman_registration_controller.dart)
- [store_registration_controller.dart](file://lib/features/auth/controllers/store_registration_controller.dart)
- [signup_body_model.dart](file://lib/features/auth/domain/models/signup_body_model.dart)
- [delivery_man_body.dart](file://lib/features/auth/domain/models/delivery_man_body.dart)
- [store_body_model.dart](file://lib/features/auth/domain/models/store_body_model.dart)
- [sign_up_screen.dart](file://lib/features/auth/screens/sign_up_screen.dart)
- [sign_up_widget.dart](file://lib/features/auth/widgets/sign_up_widget.dart)
- [delivery_man_registration_screen.dart](file://lib/features/auth/screens/delivery_man_registration_screen.dart)
- [store_registration_screen.dart](file://lib/features/auth/screens/store_registration_screen.dart)
</cite>

## Table of Contents
1. [Introduction](#introduction)
2. [Project Structure](#project-structure)
3. [Core Components](#core-components)
4. [Architecture Overview](#architecture-overview)
5. [Detailed Component Analysis](#detailed-component-analysis)
6. [Dependency Analysis](#dependency-analysis)
7. [Performance Considerations](#performance-considerations)
8. [Troubleshooting Guide](#troubleshooting-guide)
9. [Conclusion](#conclusion)

## Introduction
This document explains the registration processes across three roles: end-user customer, delivery person, and store owner/vendor. It covers the multi-step flows, form validation, submission logic, and integration with backend services. It also documents the registration data models, UI widgets, and error handling strategies used in the application.

## Project Structure
The registration feature is organized under the auth feature module with dedicated controllers, domain models, screens, and widgets. Controllers encapsulate state and orchestrate service calls; screens define multi-step UI flows; widgets implement reusable form components; and domain models represent request payloads.

```mermaid
graph TB
subgraph "Auth Feature"
A["Controllers<br/>auth_controller.dart<br/>deliveryman_registration_controller.dart<br/>store_registration_controller.dart"]
B["Domain Models<br/>signup_body_model.dart<br/>delivery_man_body.dart<br/>store_body_model.dart"]
C["Screens<br/>sign_up_screen.dart<br/>delivery_man_registration_screen.dart<br/>store_registration_screen.dart"]
D["Widgets<br/>sign_up_widget.dart"]
end
C --> A
A --> B
D --> A
```

**Diagram sources**
- [auth_controller.dart](file://lib/features/auth/controllers/auth_controller.dart)
- [deliveryman_registration_controller.dart](file://lib/features/auth/controllers/deliveryman_registration_controller.dart)
- [store_registration_controller.dart](file://lib/features/auth/controllers/store_registration_controller.dart)
- [signup_body_model.dart](file://lib/features/auth/domain/models/signup_body_model.dart)
- [delivery_man_body.dart](file://lib/features/auth/domain/models/delivery_man_body.dart)
- [store_body_model.dart](file://lib/features/auth/domain/models/store_body_model.dart)
- [sign_up_screen.dart](file://lib/features/auth/screens/sign_up_screen.dart)
- [sign_up_widget.dart](file://lib/features/auth/widgets/sign_up_widget.dart)
- [delivery_man_registration_screen.dart](file://lib/features/auth/screens/delivery_man_registration_screen.dart)
- [store_registration_screen.dart](file://lib/features/auth/screens/store_registration_screen.dart)

**Section sources**
- [auth_controller.dart](file://lib/features/auth/controllers/auth_controller.dart)
- [deliveryman_registration_controller.dart](file://lib/features/auth/controllers/deliveryman_registration_controller.dart)
- [store_registration_controller.dart](file://lib/features/auth/controllers/store_registration_controller.dart)
- [signup_body_model.dart](file://lib/features/auth/domain/models/signup_body_model.dart)
- [delivery_man_body.dart](file://lib/features/auth/domain/models/delivery_man_body.dart)
- [store_body_model.dart](file://lib/features/auth/domain/models/store_body_model.dart)
- [sign_up_screen.dart](file://lib/features/auth/screens/sign_up_screen.dart)
- [sign_up_widget.dart](file://lib/features/auth/widgets/sign_up_widget.dart)
- [delivery_man_registration_screen.dart](file://lib/features/auth/screens/delivery_man_registration_screen.dart)
- [store_registration_screen.dart](file://lib/features/auth/screens/store_registration_screen.dart)

## Core Components
- Customer registration controller orchestrates standard email/phone sign-up, handles OTP verification, and routes to verification screens when needed.
- Delivery person registration controller manages a two-step form: personal info and identity/zone/vehicle selection, plus image uploads.
- Store owner registration controller implements a multi-step wizard: vendor info, location/time preferences, optional TIN and documents, and business plan selection.

Key responsibilities:
- Validation and sanitization of user inputs.
- Preparing multipart/form-data for image/document uploads.
- Managing progress steps and navigation.
- Integrating with backend services for registration and subsequent flows.

**Section sources**
- [auth_controller.dart](file://lib/features/auth/controllers/auth_controller.dart)
- [deliveryman_registration_controller.dart](file://lib/features/auth/controllers/deliveryman_registration_controller.dart)
- [store_registration_controller.dart](file://lib/features/auth/controllers/store_registration_controller.dart)

## Architecture Overview
The registration architecture follows a layered pattern:
- Screens render multi-step UIs and collect user inputs.
- Widgets encapsulate reusable form controls and validation helpers.
- Controllers manage state, validation, and service interactions.
- Domain models serialize request payloads.
- Services handle network requests and responses.

```mermaid
sequenceDiagram
participant U as "User"
participant S as "SignUpWidget"
participant C as "AuthController"
participant M as "SignUpBodyModel"
participant B as "Backend"
U->>S : "Enter credentials and submit"
S->>S : "Validate form fields"
S->>C : "registration(SignUpBodyModel)"
C->>B : "POST /auth/register"
B-->>C : "ResponseModel(success, token or message)"
alt "Phone/email not verified"
C-->>U : "Navigate to VerificationScreen"
else "Already verified"
C-->>U : "Fetch user info and redirect"
end
```

**Diagram sources**
- [sign_up_widget.dart](file://lib/features/auth/widgets/sign_up_widget.dart)
- [auth_controller.dart](file://lib/features/auth/controllers/auth_controller.dart)
- [signup_body_model.dart](file://lib/features/auth/domain/models/signup_body_model.dart)

## Detailed Component Analysis

### Customer Registration Flow
- UI entry point is the sign-up screen containing a sign-up widget with fields for name, email, phone, password, confirm password, and referral code.
- Validation includes presence checks, email format, phone normalization, password length, and matching confirm password.
- On success, the controller triggers registration and routes to verification if phone or email is unverified; otherwise, it proceeds to profile and location setup.

```mermaid
sequenceDiagram
participant U as "User"
participant SW as "SignUpWidget"
participant AC as "AuthController"
participant API as "AuthServiceInterface"
participant VS as "VerificationScreen"
U->>SW : "Submit form"
SW->>SW : "Client-side validation"
SW->>AC : "registration(SignUpBodyModel)"
AC->>API : "registration(...)"
API-->>AC : "ResponseModel"
alt "Phone not verified"
AC-->>VS : "Open phone verification"
else "Email not verified"
AC-->>VS : "Open email verification"
else "Fully verified"
AC-->>U : "Redirect to profile/location"
end
```

**Diagram sources**
- [sign_up_widget.dart](file://lib/features/auth/widgets/sign_up_widget.dart)
- [auth_controller.dart](file://lib/features/auth/controllers/auth_controller.dart)
- [signup_body_model.dart](file://lib/features/auth/domain/models/signup_body_model.dart)

**Section sources**
- [sign_up_screen.dart](file://lib/features/auth/screens/sign_up_screen.dart)
- [sign_up_widget.dart](file://lib/features/auth/widgets/sign_up_widget.dart)
- [auth_controller.dart](file://lib/features/auth/controllers/auth_controller.dart)
- [signup_body_model.dart](file://lib/features/auth/domain/models/signup_body_model.dart)

### Delivery Person Registration Flow
- Two-step process:
  - Step 1: Profile picture upload, first/last name, phone, email, password, confirm password.
  - Step 2: Delivery type, zone, vehicle type, identity type, identity number, identity images.
- Progress tracked via a numeric status; validation ensures required fields and password strength.
- Submission builds a delivery-man payload and sends multipart data including images.

```mermaid
sequenceDiagram
participant U as "User"
participant DM as "DeliveryManRegistrationScreen"
participant DMC as "DeliverymanRegistrationController"
participant API as "DeliverymanRegistrationServiceInterface"
participant B as "Backend"
U->>DM : "Fill Step 1"
DM->>DM : "Validate Step 1"
DM->>DMC : "Update status to 0.8"
U->>DM : "Fill Step 2"
DM->>DM : "Validate Step 2"
DM->>DMC : "Prepare DeliveryManBody + images"
DMC->>API : "registerDeliveryMan(body, multipart)"
API-->>DMC : "Success/Failure"
DMC-->>U : "Show snackbar and navigate"
```

**Diagram sources**
- [delivery_man_registration_screen.dart](file://lib/features/auth/screens/delivery_man_registration_screen.dart)
- [deliveryman_registration_controller.dart](file://lib/features/auth/controllers/deliveryman_registration_controller.dart)
- [delivery_man_body.dart](file://lib/features/auth/domain/models/delivery_man_body.dart)

**Section sources**
- [delivery_man_registration_screen.dart](file://lib/features/auth/screens/delivery_man_registration_screen.dart)
- [deliveryman_registration_controller.dart](file://lib/features/auth/controllers/deliveryman_registration_controller.dart)
- [delivery_man_body.dart](file://lib/features/auth/domain/models/delivery_man_body.dart)

### Store Owner/Vendor Registration Flow
- Multi-step wizard:
  - Step 1: Vendor info (multi-language tabs), logo/cover images, location picker, delivery time window, TIN and expiry date, TIN certificate uploads.
  - Step 2: Module selection and zone availability check.
  - Step 3: Business plan selection and subscription handling.
- Progress tracked via a numeric status; validation ensures required fields and file size limits.
- Submission prepares store body with translations, coordinates, and optional TIN fields, plus multipart documents.

```mermaid
sequenceDiagram
participant U as "User"
participant SR as "StoreRegistrationScreen"
participant SRC as "StoreRegistrationController"
participant API as "StoreRegistrationServiceInterface"
participant HC as "HomeController"
participant BC as "BusinessController"
U->>SR : "Fill Step 1"
SR->>SRC : "Update store status to 0.6"
U->>SR : "Fill Step 2"
SR->>SRC : "Update status to 0.9"
U->>SR : "Select business plan"
SR->>SRC : "registerStore(StoreBodyModel, images, documents)"
SRC->>API : "POST /stores/register"
API-->>SRC : "Response with store_id, package_id"
alt "No package"
SRC->>BC : "submitBusinessPlan(...)"
else "Has package"
SRC->>HC : "Save shared pref"
SRC-->>U : "Navigate to subscription payment"
end
```

**Diagram sources**
- [store_registration_screen.dart](file://lib/features/auth/screens/store_registration_screen.dart)
- [store_registration_controller.dart](file://lib/features/auth/controllers/store_registration_controller.dart)
- [store_body_model.dart](file://lib/features/auth/domain/models/store_body_model.dart)

**Section sources**
- [store_registration_screen.dart](file://lib/features/auth/screens/store_registration_screen.dart)
- [store_registration_controller.dart](file://lib/features/auth/controllers/store_registration_controller.dart)
- [store_body_model.dart](file://lib/features/auth/domain/models/store_body_model.dart)

### Registration Body Models
- Customer registration payload: name, email, phone, password, optional referral code, device token, guest ID.
- Delivery person payload: first/last name, phone, email, password, identity type/number, earnings preference, zone ID, vehicle ID.
- Store owner payload: translated store name/address, delivery time bounds, coordinates, owner contact, zone/module, business plan, package, optional TIN and expiry, and pickup zone IDs.

Validation and serialization:
- Each model exposes a constructor and JSON conversion methods to prepare backend payloads.
- Password strength indicators and checks are handled in respective controllers.

**Section sources**
- [signup_body_model.dart](file://lib/features/auth/domain/models/signup_body_model.dart)
- [delivery_man_body.dart](file://lib/features/auth/domain/models/delivery_man_body.dart)
- [store_body_model.dart](file://lib/features/auth/domain/models/store_body_model.dart)

### Validation Logic and Error Handling
- Client-side validation:
  - Presence checks, email format, phone normalization, password length and strength, confirm password match, and TIN/document constraints.
  - Password strength is evaluated with separate flags for length, numbers, uppercase, lowercase, and special characters.
- Backend-driven verification:
  - After registration, if phone or email is not verified, the system opens a verification screen for OTP/email confirmation.
- Snackbars and dialogs surface errors and guide users to correct inputs.

Common validations:
- Name, email, phone, password, confirm password, identity number, images/documents, and module/zone selections.

**Section sources**
- [sign_up_widget.dart](file://lib/features/auth/widgets/sign_up_widget.dart)
- [deliveryman_registration_controller.dart](file://lib/features/auth/controllers/deliveryman_registration_controller.dart)
- [store_registration_controller.dart](file://lib/features/auth/controllers/store_registration_controller.dart)

### Configuration Options and Workflows
- Role-based flows:
  - Customer registration supports phone/email verification and redirects to profile/location after success.
  - Delivery person registration requires identity images and vehicle selection.
  - Store owner registration integrates with business plans and subscriptions.
- Dynamic UI:
  - Multi-language tabs for store names.
  - Conditional fields based on configuration flags (e.g., referral code visibility).
- Approval workflows:
  - Store registration may route to subscription/payment depending on package selection.

**Section sources**
- [auth_controller.dart](file://lib/features/auth/controllers/auth_controller.dart)
- [store_registration_controller.dart](file://lib/features/auth/controllers/store_registration_controller.dart)
- [store_registration_screen.dart](file://lib/features/auth/screens/store_registration_screen.dart)

## Dependency Analysis
Controllers depend on:
- Domain models for request payloads.
- Services for backend communication.
- UI widgets for form rendering and validation.
- Other controllers for cross-feature operations (e.g., saving registration completion state).

```mermaid
graph LR
SW["SignUpWidget"] --> AC["AuthController"]
AC --> SBM["SignUpBodyModel"]
DMRS["DeliveryManRegistrationScreen"] --> DMC["DeliverymanRegistrationController"]
DMC --> DMB["DeliveryManBody"]
SR["StoreRegistrationScreen"] --> SRC["StoreRegistrationController"]
SRC --> SBM2["StoreBodyModel"]
DMC --> API1["DeliverymanRegistrationServiceInterface"]
SRC --> API2["StoreRegistrationServiceInterface"]
AC --> API3["AuthServiceInterface"]
```

**Diagram sources**
- [sign_up_widget.dart](file://lib/features/auth/widgets/sign_up_widget.dart)
- [auth_controller.dart](file://lib/features/auth/controllers/auth_controller.dart)
- [signup_body_model.dart](file://lib/features/auth/domain/models/signup_body_model.dart)
- [delivery_man_registration_screen.dart](file://lib/features/auth/screens/delivery_man_registration_screen.dart)
- [deliveryman_registration_controller.dart](file://lib/features/auth/controllers/deliveryman_registration_controller.dart)
- [delivery_man_body.dart](file://lib/features/auth/domain/models/delivery_man_body.dart)
- [store_registration_screen.dart](file://lib/features/auth/screens/store_registration_screen.dart)
- [store_registration_controller.dart](file://lib/features/auth/controllers/store_registration_controller.dart)
- [store_body_model.dart](file://lib/features/auth/domain/models/store_body_model.dart)

**Section sources**
- [auth_controller.dart](file://lib/features/auth/controllers/auth_controller.dart)
- [deliveryman_registration_controller.dart](file://lib/features/auth/controllers/deliveryman_registration_controller.dart)
- [store_registration_controller.dart](file://lib/features/auth/controllers/store_registration_controller.dart)
- [signup_body_model.dart](file://lib/features/auth/domain/models/signup_body_model.dart)
- [delivery_man_body.dart](file://lib/features/auth/domain/models/delivery_man_body.dart)
- [store_body_model.dart](file://lib/features/auth/domain/models/store_body_model.dart)

## Performance Considerations
- Minimize unnecessary rebuilds by updating only the required controller state.
- Defer heavy operations (image/document uploads) until validation passes.
- Use progress indicators to reflect multi-step status and avoid redundant submissions.
- Cache small configuration values (e.g., default location) to reduce repeated lookups.

## Troubleshooting Guide
Common issues and resolutions:
- Invalid phone number: Ensure international format and normalized number before submission.
- Password does not meet strength criteria: Enforce minimum length and include mixed-case letters, digits, and special characters.
- Missing required fields: Provide clear snackbars indicating which fields are empty or invalid.
- Upload failures: Verify file size limits and supported formats for images/documents.
- Navigation after verification: Confirm that verification routes are correctly opened based on unverified channels (phone/email).

**Section sources**
- [sign_up_widget.dart](file://lib/features/auth/widgets/sign_up_widget.dart)
- [deliveryman_registration_controller.dart](file://lib/features/auth/controllers/deliveryman_registration_controller.dart)
- [store_registration_controller.dart](file://lib/features/auth/controllers/store_registration_controller.dart)

## Conclusion
The registration subsystem provides robust, role-specific flows with strong client-side validation and clear backend integration. The modular design of controllers, models, screens, and widgets enables maintainability and extensibility. By following the documented flows and validation strategies, teams can confidently enhance or troubleshoot registration experiences across customers, delivery persons, and store owners.