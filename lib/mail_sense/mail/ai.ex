defmodule MailSense.Mail.AI do
  @model "gpt-4o-mini"

  def summarize_and_categorize(email_fields, categories) do
    prompt = build_prompt(email_fields, categories)

    body = %{
      model: @model,
      temperature: 0.2,
      messages: [
        %{
          role: "system",
          content: "You classify emails into the best category and write a brief summary."
        },
        %{role: "user", content: prompt}
      ]
    }

    headers = [{"authorization", "Bearer " <> System.fetch_env!("OPENAI_API_KEY")}]

    case Req.post("https://api.openai.com/v1/chat/completions", json: body, headers: headers) do
      {:ok, %{status: 200, body: %{"choices" => [%{"message" => %{"content" => content}} | _]}}} ->
        Jason.decode(content)

      other ->
        {:error, other}
    end
  end

  defp build_prompt(email, categories) do
    cats = Enum.map_join(categories, "\n", fn c -> "- #{c.name}: #{c.description || ""}" end)

    """
    Return JSON with keys: category, reason, summary.


    Categories:
    #{cats}


    Email:
    From: #{email.from}
    Subject: #{email.subject}
    Snippet: #{email.snippet}
    Body (text excerpt): #{String.slice(email.body_text || "", 0, 2000)}
    """
  end
end
