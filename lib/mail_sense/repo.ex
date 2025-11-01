defmodule MailSense.Repo do
  use Ecto.Repo,
    otp_app: :mail_sense,
    adapter: Ecto.Adapters.Postgres
end
