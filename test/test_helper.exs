ExUnit.start()
Ecto.Adapters.SQL.Sandbox.mode(MailSense.Repo, :manual)
Mox.defmock(MailSense.HTTPMock, for: MailSense.HTTPClient)
