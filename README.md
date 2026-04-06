# Water

Trying to take care of the garden one app at a time.

## Running locally

### Running in dev mode

Use Docker for Postgres and run Phoenix on the host for the fastest reload cycle.

1. Start Postgres:

```bash
docker compose up db
```

2. Install dependencies, create/migrate the database, and build assets:

```bash
mix setup
```

3. Start Phoenix:

```bash
mix phx.server
```

4. Go to [`http://localhost:4000`](http://localhost:4000) and authenticate with something like:
- username: `alice`
- password: `replace-this-basic-auth-password`

5. For testing use a mix of test commands:

```bash
mix test.unit
mix test.full
mix precommit
```

### Running the full stack

Use the full Docker stack for onboarding, smoke testing, and verifying the whole app runs together.

```bash
docker compose up --build
```

This boots both the app and Postgres, runs migrations and seeds inside the app container, and serves the app on [`http://localhost:4000`](http://localhost:4000).

## Learn more

* Official website: https://www.phoenixframework.org/
* Guides: https://hexdocs.pm/phoenix/overview.html
* Docs: https://hexdocs.pm/phoenix
* Forum: https://elixirforum.com/c/phoenix-forum
* Source: https://github.com/phoenixframework/phoenix
