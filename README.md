# AnnotAt

A service for automatically publishing content to the Atmosphere, using the standard.site lexicon. Register your publication and a discovery mechanism, and your content is automatically published.

## TODO

- [x] Sign up/sign in with Bluesky
- [ ] Maybe some design?
- [ ] Add site including verification
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
