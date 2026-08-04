# annot.at

*This is a work in progress. Feel free to poke around and take it for a spin, but keep in mind it's very much under development.*

A service for automatically publishing content to the Atmosphere, using the standard.site lexicon. Register your publication and a discovery mechanism, and your content is automatically published.

Stay up to date on development at [blog.annot.at](https://blog.annot.at).

## How it works

[annot.at](https://annot.at) enables you to log in using your atproto account, whether that's Bluesky, Eurosky, or your own PDS. it will ask for permission to write to the standard.site lexicon on your behalf.

The app uses a few different things from your blog to accomplish this, and it requires some setup:

1. During the site setup wizard we generate a record key for your publication if you don't have one yet, you will get instructions to host this key in your site under `/.well-known/site.standard.publication`.
2. You need a well-formed RSS or Atom feed that contains your posts.
3. Each page that you want to upload needs to have a `<link rel="site.standard.document" href="<at-uri>"` field set, this is what eg Bluesky uses to validate the standard.site document.

Document rkeys have to be TIDs to be valid, and need to be stable, so either generate them and store them in your blog post fronmatter/metadata, or use a deterministic implementation that can run multiple times for the same post and give the same result.

annot.at will use information from your blog to publish your documents. From the feed it gets title, description, content, tags, and published_at. From the blog post page itself it gets the open graph image and the record key.

## TODO

- [x] Sign up/sign in with Bluesky
- [x] Maybe some design?
- [x] Add site including verification
- [x] Document cover images
- [x] Document content with html content type
- [ ] Support multiple publications on the same site
- [ ] RSS poller
- [ ] standard.site document reader
- [ ] Post to Bluesky
- [ ] Let atproto drive things more
  - [x] List publications, including not explicitly added ones
  - [x] List documents, including not explicitly added ones
  - [ ] List dangling documents/documents that no longer validate against post etc

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
