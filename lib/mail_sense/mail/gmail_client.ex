defmodule MailSense.Mail.GmailClient do
  alias GoogleApi.Gmail.V1.Api.Users
  alias GoogleApi.Gmail.V1.Connection
  alias GoogleApi.Gmail.V1.Model.ModifyMessageRequest
  alias Tesla.Client, as: TeslaClient

  @http_client Application.compile_env(:mail_sense, :http_client)
  @gmail_api Application.compile_env(:mail_sense, MailSense.HTTP)[:gmail_api_base] ||
               "https://gmail.googleapis.com"

  def connection(access_token), do: Connection.new("Bearer " <> access_token)

  def modify_labels(conn_or_token, user_id, message_id, add_labels \\ [], remove_labels \\ [])

  def modify_labels(
        %TeslaClient{} = conn,
        user_id,
        message_id,
        add_labels,
        remove_labels
      ) do
    body = %ModifyMessageRequest{addLabelIds: add_labels, removeLabelIds: remove_labels}
    Users.gmail_users_messages_modify(conn, user_id, message_id, body)
  end

  def modify_labels(token, user_id, message_id, add_labels, remove_labels)
      when is_binary(token) do
    body = %{"addLabelIds" => add_labels, "removeLabelIds" => remove_labels}

    @http_client.post(
      "#{@gmail_api}/users/#{user_id}/messages/#{message_id}/modify",
      json: body,
      headers: [{"authorization", "Bearer " <> token}],
      follow_redirects: true,
      max_redirects: 5,
      receive_timeout: 8_000,
      connect_timeout: 5_000
    )
  end

  def modify_labels_batch(conn_or_token, user_id, updates) when is_list(updates) do
    Enum.map(updates, fn {msg_id, adds, removes} ->
      modify_labels(conn_or_token, user_id, msg_id, adds, removes)
    end)
  end

  def list_new_messages(conn_or_token, user_email, q, page_token \\ nil)

  def list_new_messages(%TeslaClient{} = conn, user_email, q, page_token) do
    Users.gmail_users_messages_list(conn, user_email,
      q: q,
      page_token: page_token,
      max_results: 50
    )
  end

  def list_new_messages(token, user_email, q, page_token) when is_binary(token) do
    params =
      [q: q, maxResults: 50]
      |> then(fn p -> if page_token, do: p ++ [pageToken: page_token], else: p end)

    @http_client.get(
      "#{@gmail_api}/users/#{user_email}/messages",
      params: params,
      headers: [{"authorization", "Bearer " <> token}]
    )
  end

  def get_message(conn_or_token, user_email, id, format \\ "full")

  def get_message(%TeslaClient{} = conn, user_email, id, format),
    do: Users.gmail_users_messages_get(conn, user_email, id, format: format)

  def get_message(token, user_email, id, format) when is_binary(token) do
    Req.get(
      "#{@gmail_api}/users/#{user_email}/messages/#{id}",
      params: [format: format],
      headers: [{"authorization", "Bearer " <> token}]
    )
  end

  def batch_delete(%TeslaClient{} = conn, user_email, ids),
    do: Users.gmail_users_messages_batch_delete(conn, user_email, %{ids: ids})

  def batch_delete(token, user_email, ids) when is_list(ids) and is_binary(token) do
    Req.post(
      "#{@gmail_api}/users/#{user_email}/messages/batchDelete",
      json: %{"ids" => ids},
      headers: [{"authorization", "Bearer " <> token}]
    )
  end

  def send_raw(%TeslaClient{} = conn, user_email, raw_b64url),
    do: Users.gmail_users_messages_send(conn, user_email, %{raw: raw_b64url})

  def send_raw(token, user_email, raw_b64url) when is_binary(token) do
    @http_client.post(
      "#{@gmail_api}/users/#{user_email}/messages/send",
      json: %{"raw" => raw_b64url},
      headers: [{"authorization", "Bearer " <> token}]
    )
  end

  def list_history(conn, user_email, start_history_id \\ nil) do
    Users.gmail_users_history_list(conn, user_email,
      start_history_id: start_history_id,
      history_types: ["messageAdded"],
      max_results: 100
    )
  end

  def get_profile(conn, user_email) do
    Users.gmail_users_get_profile(conn, user_email)
  end

  def create_label(conn, user_email, name) do
    body = %{name: name, labelListVisibility: "labelShow", messageListVisibility: "show"}
    Users.gmail_users_labels_create(conn, user_email, body)
  end
end
