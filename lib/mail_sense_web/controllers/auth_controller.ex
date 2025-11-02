defmodule MailSenseWeb.AuthController do
  use MailSenseWeb, :controller

  plug Ueberauth

  alias MailSense.Accounts

  def request(conn, _params), do: redirect(conn, to: "/auth/google")

  def callback(%{assigns: %{ueberauth: auth}} = conn, _params) do
    %{email: email, name: name} = auth.info
    %{token: token, refresh_token: refresh_token, expires_at: expires_at} = auth.credentials

    user = Accounts.get_or_create_user!(email, name)

    Accounts.upsert_gmail_account!(user, %{
      email: email,
      access_token: token,
      refresh_token: refresh_token,
      expires_at: DateTime.from_unix!(expires_at)
    })

    conn
    |> put_session(:user_id, user.id)
    |> redirect(to: "/")
  end

  def delete(conn, _) do
    conn
    |> configure_session(drop: true)
    |> redirect(to: "/")
  end
end
