defmodule MailSense.Mail.GmailClientTest do
  use MailSense.DataCase, async: true
  import Mox
  alias MailSense.Mail.GmailClient

  setup :set_mox_from_context
  setup :verify_on_exit!

  setup do
    # Swap in the mock for this test process
    original = Application.get_env(:mail_sense, :http_client)
    Application.put_env(:mail_sense, :http_client, MailSense.HTTPMock)

    # Make sure base is something stable (optional)
    base_cfg = Application.get_env(:mail_sense, MailSense.HTTP, [])
    original_base = Keyword.get(base_cfg, :gmail_api_base)

    Application.put_env(
      :mail_sense,
      MailSense.HTTP,
      Keyword.put(base_cfg, :gmail_api_base, "https://gmail.googleapis.com")
    )

    on_exit(fn ->
      Application.put_env(:mail_sense, :http_client, original)
      base_cfg2 = Application.get_env(:mail_sense, MailSense.HTTP, [])

      Application.put_env(
        :mail_sense,
        MailSense.HTTP,
        Keyword.put(base_cfg2, :gmail_api_base, original_base)
      )
    end)

    :ok
  end

  test "modify_labels removes INBOX" do
    expect(MailSense.HTTPMock, :post, fn url, body, opts ->
      assert url == "https://gmail.googleapis.com/gmail/v1/users/me/messages/abc/modify"
      assert body["removeLabelIds"] == ["INBOX"]
      assert body["addLabelIds"] == []
      {:ok, %{status: 200, body: %{"id" => "abc"}}}
    end)

    assert {:ok, %{status: 200}} =
             GmailClient.modify_labels("token", "me", "abc", [], ["INBOX"])
  end

  test "list_new_messages sends q and pageToken" do
    expect(MailSense.HTTPMock, :get, fn url, opts ->
      assert url == "https://gmail.googleapis.com/gmail/v1/users/me/messages"
      params = Keyword.get(opts, :params, [])
      # normalize to a map for easy compare
      assert Map.new(params) == %{"q" => "label:inbox", "pageToken" => "pt1"}
      {:ok, %{status: 200, body: %{"messages" => [%{"id" => "1"}]}}}
    end)

    assert {:ok, %{status: 200, body: %{"messages" => [%{"id" => "1"}]}}} =
             GmailClient.list_new_messages("token", "me", "label:inbox", "pt1")
  end
end
