# AnnotAt

A service for automatically publishing content to the Atmosphere, using the standard.site lexicon. Register your publication and a discovery mechanism, and your content is automatically published.

Requires your site to have a `link rel=alternate` for a feed set, and that you're able to verify your ownership by serving a `/.well-known` file.

## TODO

- [x] Sign up/sign in with Bluesky
- [x] Maybe some design?
- [x] Add site including verification
- [ ] RSS poller
- [ ] standard.site document reader
- [ ] Post to Bluesky

## Authenticating

You can run the app locally and try out the full OAuth flow by exposing it to the internet using Tailscale or similar solutions. For example:

```
> tailscale funnel 4002
Available on the internet:

https://machine.random-thing.ts.net/
|-- proxy http://127.0.0.1:4002

Press Ctrl+C to exit.
```

Make sure that same host is set in `dev.exs` and the app has been restarted. Click login and use any active atproto handle, and you should be able to OAuth against it.

## Deploying

You need to set up some env vars to run this service in a production environment, `SECRET_KEY_BASE`, `DATABASE_URL`, `HOST`, `CLOAK_KEY`, and `ATPROTO_CLIENT_PRIVATE_JWK`.

- `SECRET_KEY_BASE` - run `mix phx.gen.secret 64` and copy the output
- `DATABASE_URL` - a Postgres database URL like `postgresql://app:pass@db:5432/db_name`
- `HOST` - a domain name like `annot.at`
- `CLOAK_KEY` - run `mix run -e 'IO.puts(Base.encode64(:crypto.strong_rand_bytes(32)))'` and copy the output
- `ATPROTO_CLIENT_PRIVATE_JWK` - run `mix run -e '{_, jwk} = JOSE.JWK.to_map(JOSE.JWK.generate_key({:ec, "P-256"})); IO.puts(Jason.encode!(jwk))'` and copy the output

Note that `ATPROTO_CLIENT_PRIVATE_JWK`, `CLOAK_KEY`, and `SECRET_KEY_BASE` are secrets and should not be shared.
