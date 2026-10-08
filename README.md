# PartTimeNow

PartTimeNow is a cross-platform part-time recruitment application developed with Flutter. The system is designed to connect Job Seekers and Employers in a simple and structured recruitment process, while also providing a protected administrative area for system management.

The application supports role-based access, job search and filtering, application submission, application tracking, and employer-side applicant review. A local persistence layer is used for data storage during the prototype stage, while the architecture is organized so it can later be replaced by a Django or backend-driven system without changing the presentation layer.

## Overview

PartTimeNow allows:

- Job Seekers to register, log in, search for jobs, view details, save preferred jobs, and apply with a cover letter.
- Employers to create and manage job postings, review applicants, and update application statuses.
- Administrators to manage users and job listings in a protected area.

## Key Features

- User registration and login
- Role-based access control for Job Seeker, Employer, and Administrator
- Job search by keyword and location
- Expired jobs automatically excluded from available search results
- Job detail viewing
- Cover letter application submission
- Duplicate application prevention
- Saved/Favourite jobs functionality
- My Applications tracking with status updates
- Employer job creation, update, and archive support
- Employer-configured requirements, job type, salary, and application deadline
- Applicant review with reviewer notes
- Applicant contact details shown to the owning employer
- Application workflow: Pending -> Reviewing -> Accepted / Rejected
- Local persistence for users, jobs, applications, and favourites
- Protected admin moderation functions with confirmation dialogs
- Administrator system monitoring for users, jobs, and applications
- Coordinated cleanup of jobs, applications, favourites, and applicant counts when accounts are removed

## System Architecture

The project follows a three-layer architecture:

1. Presentation Layer
   - Flutter screens and user interface components
   - Authentication screens and dashboards
   - Role-aware navigation

2. Application Layer
   - Business rules and validation logic
   - Authentication services
   - Job and application workflows
   - Access control checks

3. Data Layer
   - SharedPreferences-based persistence
   - JSON serialization for application data
   - Local storage for prototype testing

The internal Flutter package identifier remains `flutter_application_1` for compatibility with existing imports and platform package configuration. The user-facing product name is `PartTimeNow`.

This separation keeps the application modular and makes it easier to replace the local storage layer with a database-backed server in the future.

## Security Design

The security design of PartTimeNow focuses on protecting user accounts, job information, application records, and other system data from unauthorized access. Since the platform supports different user types, each user should only access functions and information related to their role.

### Security Measures

- User Authentication
  - Only registered users can access protected areas.
- Role-Based Access Control
  - Job Seekers and Employers have separate permissions.
- Password Hashing
  - Passwords are stored in hash form instead of plain text.
- Input Validation
  - Registration, job creation, and application forms are validated before storing data.
- Application Access Control
  - Job Seekers can only view their own applications.
  - Employers can only manage applications for their own job listings.
- Job Ownership Control
  - Employers can manage only their own job posts.
- Duplicate Protection
  - A user cannot apply to the same job more than once.

### Web Security Note

CSRF protection is required when the application is connected to an HTTP backend. The current Flutter prototype stores data locally using SharedPreferences, so browser-based CSRF tokens are not required in this stage. In a future Django-based deployment, server-side authentication and CSRF protection should be enabled to secure form-based requests.

## Recruitment Workflow

The overall workflow is as follows:

1. User registers or logs in.
2. The system identifies the user role.
3. Job Seekers search for jobs and view job details.
4. Job Seekers submit applications with a cover letter.
5. The application is stored with the status Pending.
6. Employers review applicants and manage recruitment decisions.
7. Employers update the application status to Reviewing, Accepted, or Rejected.
8. Job Seekers can view the updated application status in My Applications.
9. The recruitment process is completed after the final decision is recorded.

## Project Structure

```text
lib/
  data/              # schema and architecture metadata
  models/            # application models
  screens/           # authentication screens
  main.dart          # dashboards and role-based application screens
  services/          # authentication, jobs, applications, favourites
  widgets/           # reusable UI components

test/
  services/          # workflow, security, and data-integrity tests
```

## UI Page Flow

The interface is organized around role-specific functions:

- Job Seeker:
  - Register Account
  - Login and Logout
  - Search Jobs
  - View Job Details
  - Save/Favourite Job
  - View Saved Jobs
  - Apply for Job
  - Submit Cover Letter
  - View My Applications
  - Track Application Status

- Employer:
  - Register Account
  - Login and Logout
  - Create Job Listing
  - View Job Listings
  - Edit Job Listing
  - Manage Job Listings
  - View Applicants
  - Review Applications
  - Update Application Status

- Administrator:
  - Protected Login
  - Manage User Accounts
  - Manage Job Listings
  - Manage System Data
  - Monitor System

## Running the Project

### Install dependencies

```powershell
flutter pub get
```

### Run the app

```powershell
flutter run
```

### Run tests

```powershell
flutter test
```

### Run static analysis

```powershell
flutter analyze
```

### Build web

```powershell
flutter build web --no-wasm-dry-run
```

### Build Android APK

```powershell
$env:JAVA_HOME = "C:\Program Files\Eclipse Adoptium\jdk-21.0.12.101-hotspot"
flutter build apk --release
```

The APK output is generated in:

```text
build/app/outputs/flutter-apk/app-release.apk
```

## Demo Administrator

The prototype includes a seeded administrator account for testing:

- Email: admin@parttimenow.local
- Password: Admin123!

This account is created locally for demonstration and testing. In a production environment, authentication and authorization should be handled by a secure backend with salted password hashing, HTTPS, and server-side access control.

## Notes

This project is currently a Flutter prototype with local data persistence. It demonstrates the full PartTimeNow recruitment workflow and validates the core logic through automated service tests. The system is structured for future extension into a full-stack solution with backend APIs and database storage.

The current automated test suite contains 17 service tests covering authentication, role permissions, job listing management, search filters, applications, favourites, status transitions, administrator monitoring, and account data cleanup.
