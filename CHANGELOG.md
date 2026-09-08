## 0.1.0

- Initial version.

## 1.0.0

- First Release.
- ORM, Error Pages,

## 1.0.4
- Form Inputs
- Body Parsing

## 1.0.5
- Formatting

## 1.1.0
- Stable v1

## 1.1.1
- dart docs


## 1.2.0
- Auth

## 1.2.1
- Sessions

## 1.2.2
- Body Parser -> FormRequest

## 1.3.0
- Redesign of FormRequest to address request body stream consumption
- @csrf directive for view templates
- csrf token

## 1.3.1
- Postgres and s3 models
- minor fixes for file uploads
- cors middleware

## 1.3.2
- types safe Request/Route Model binding
- s3 client provider
- update landing pages

## 1.3.3
- mixin for Model instance db operations
- rm default pgsql init in App boot

## 1.3.4
- HasOne, HasMany, BelongsTo on Model

## 1.4.0
- Hashing API changes
  - Hasher.hasherPassword -> Hasher.make()
  - Hasher.verifyPassword -> Hasher.check()
  - Hashing Ext on Auth   -> Auth.hashPassword
  - Hashing Ext on Auth   -> Auth.verifyPassword Sessions
- Sessions
  - {{ session }} available to all views
  - session.user    -> nullable
  - session.errors  -> empty
  - use request.thisSession.errors.addAll()
- Templates API changes
  - {{ user }} -> {{ session.user }}
  - errors     -> {{ session.errors }}
  - data       -> {{ session.data }}

## 1.4.1
- Minor fixes 
- Docs

## 1.5.0
- SES Client
  - AWS ses client for sending mail
  - uses config('env.aws')
  - sesClient.sendEmail({opts});
- Model Relationships (w/ beta features)
  - hasOne<T>
  - hasMany<T>
  - belongsToOne<T>
  - belongsToMany<T>()
  - model.attach(sibling) 
  - model.detach(sibling)
- Pivot Tables
  - used for belongsToMany relationships
- Roles
  - built-in user roles
- Flash Messages
  - request.flash(key,message)
  - uses FlashMessaging.middleware() to manage flash data life cycle
- Request Validation 
  - request.validate(field, rules)
  - request.validateAll([{"field" : [Rules]}])
  - validation Rules
- Form Data
  - value = "{{ session.data.<name>}}"
  - template directive old('<name>') planned
- Queue
  - A functional approach to Queues

## 1.6.0
- Template Engine rewrite
  - From regex based template parsing to AST 
- Sessions and Auth rewrite
  - From single auth session to multi-auth sessions
  - user remains logged in on server restart
- request.form() to request.form
  - changed extension from method to getter
- frontend assets
  - added support for css/js with vite
  - adopted alpine js and tailwind by default
- AppStatus.shuttingDown to AppStatus.shutdown
- App.env as static getter
- Cleanup at shutdown

## 1.6.1
## 1.6.2
## 1.6.3
## 1.6.4
## 1.6.5