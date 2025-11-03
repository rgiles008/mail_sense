defmodule MailSense.Mail.AI do
  @model "gpt-4o-mini"

  @open_ai_base Application.compile_env(:mail_sense, MailSense.HTTP)[:openai_api_base] ||
                  "https://api.openai.com"

  def tie_break_and_summarize(email_fields, candidates) do
    cats = Enum.map_join(candidates, "\n", &("- " <> &1.name <> ": " <> (&1.description || "")))

    prompt = """
    You will (1) choose the SINGLE best category from the list and (2) write a 1-2 sentence summary.
    Respond as JSON: {"category": "name", "reason": "...", "summary": "..."}

    Categories:
    #{cats}

    Email:
    From: #{email_fields.from}
    Subject: #{email_fields.subject}
    Snippet: #{email_fields.snippet}
    Body: #{String.slice(email_fields.body_text || "", 0, 2000)}
    """

    body = %{
      model: @model,
      temperature: 0.2,
      messages: [
        %{role: "system", content: "You classify emails and summarize briefly."},
        %{role: "user", content: prompt}
      ]
    }

    headers = [{"authorization", "Bearer " <> System.fetch_env!("OPENAI_API_KEY")}]

    case Req.post(@open_ai_base, json: body, headers: headers) do
      {:ok, %{status: 200, body: %{"choices" => [%{"message" => %{"content" => content}} | _]}}} ->
        Jason.decode(content)

      other ->
        {:error, other}
    end
  end

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

    case Req.post(@open_ai_base, json: body, headers: headers) do
      {:ok, %{status: 200, body: %{"choices" => [%{"message" => %{"content" => content}} | _]}}} ->
        Jason.decode(content)

      other ->
        {:error, other}
    end
  end

  def summarize(email_fields) do
    prompt = build_summary_prompt(email_fields)

    body = %{
      model: @model,
      temperature: 0.2,
      messages: [
        %{role: "system", content: "You write one-sentence summaries of emails."},
        %{role: "user", content: prompt}
      ]
    }

    headers = [{"authorization", "Bearer " <> System.fetch_env!("OPENAI_API_KEY")}]

    case Req.post(@open_ai_base, json: body, headers: headers) do
      {:ok, %{status: 200, body: %{"choices" => [%{"message" => %{"content" => summary}} | _]}}} ->
        {:ok, String.trim(summary)}

      other ->
        {:error, other}
    end
  end

  defp build_summary_prompt(email) do
    body = (email.body_text || "") |> String.slice(0, 4000)

    """
    Summarize this email in ONE concise sentence (<= 35 words), no preface.

    Subject: #{email.subject}
    From: #{email.from}
    Body:
    #{body}
    """
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
