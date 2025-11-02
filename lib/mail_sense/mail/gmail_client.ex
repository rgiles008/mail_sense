defmodule MailSense.Mail.GmailClient do
  alias GoogleApi.Gmail.V1.Api.Users
  alias GoogleApi.Gmail.V1.Connection

  def connection(access_token), do: Connection.new("Bearer " <> access_token)

  def list_new_messages(conn, user_email, q, page_token \\ nil) do
    Users.gmail_users_messages_list(conn, user_email,
      q: q,
      page_token: page_token,
      max_results: 50
    )
  end

  def get_message(conn, user_email, id, format \\ "full"),
    do: Users.gmail_users_messages_get(conn, user_email, id, format: format)

  def modify_labels(conn, user_email, id, add_labels \\ [], remove_labels \\ []) do
    Users.gmail_users_messages_modify(conn, user_email, id, %{
      addLabelIds: add_labels,
      removeLabelIds: remove_labels
    })
  end

  def batch_delete(conn, user_email, ids),
    do: Users.gmail_users_messages_batch_delete(conn, user_email, %{ids: ids})

  def send_raw(conn, user_email, raw_b64url),
    do: Users.gmail_users_messages_send(conn, user_email, %{raw: raw_b64url})
end
