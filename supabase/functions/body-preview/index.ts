type BodyPreviewRequest = {
  imageBase64?: string;
  mimeType?: string;
  protocolName?: string;
};

type ImageProvider = "openai" | "nano-banana-2";

const openAIApiKey = Deno.env.get("OPENAI_API_KEY");
const geminiApiKey =
  Deno.env.get("GEMINI_API_KEY") ?? Deno.env.get("GOOGLE_API_KEY");

// Backend-only switch. The iOS app always calls this same edge function.
const imageProvider = resolveImageProvider(
  Deno.env.get("BODY_PREVIEW_IMAGE_PROVIDER") ?? "openai",
);
const openAIImageModel =
  Deno.env.get("BODY_PREVIEW_OPENAI_MODEL") ?? "gpt-image-2";
const geminiImageModel = normalizeGeminiModel(
  Deno.env.get("BODY_PREVIEW_GEMINI_MODEL") ?? "gemini-3.1-flash-image",
);
const geminiAspectRatio =
  Deno.env.get("BODY_PREVIEW_GEMINI_ASPECT_RATIO") ?? "2:3";
const geminiImageSize = Deno.env.get("BODY_PREVIEW_GEMINI_IMAGE_SIZE") ?? "1K";

function resolveImageProvider(rawProvider: string): ImageProvider {
  const provider = rawProvider.trim().toLowerCase();

  switch (provider) {
    case "openai":
    case "gpt-image":
    case "gpt-image-2":
      return "openai";
    case "google":
    case "gemini":
    case "nano-banana":
    case "nanobanana":
    case "nano-banana-2":
    case "nano_banana_2":
    case "nanobanana2":
    case "nano banana 2":
    case "gemini-3.1-flash-image":
      return "nano-banana-2";
    default:
      return "openai";
  }
}

function normalizeGeminiModel(rawModel: string) {
  return rawModel.trim().replace(/^models\//, "");
}

type ImageGenerationResult = {
  imageBase64: string;
};

type GeminiInlineData = {
  data?: string;
  mimeType?: string;
  mime_type?: string;
};

type GeminiPart = {
  text?: string;
  inlineData?: GeminiInlineData;
  inline_data?: GeminiInlineData;
};

function decodeBase64Image(imageBase64: string) {
  const binary = atob(imageBase64);
  const bytes = new Uint8Array(binary.length);

  for (let index = 0; index < binary.length; index += 1) {
    bytes[index] = binary.charCodeAt(index);
  }

  return bytes;
}

function jsonResponse(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      "Content-Type": "application/json",
    },
  });
}

async function generateOpenAIPreview(
  imageBytes: Uint8Array,
  mimeType: string,
  prompt: string,
): Promise<ImageGenerationResult> {
  if (!openAIApiKey) {
    throw new Error("OPENAI_API_KEY is not configured.");
  }

  const formData = new FormData();
  formData.append("model", openAIImageModel);
  formData.append(
    "image[]",
    new Blob([imageBytes.buffer as ArrayBuffer], { type: mimeType }),
    "body-preview.jpg",
  );
  formData.append("prompt", prompt);
  formData.append("size", "1024x1536");
  formData.append("quality", "medium");
  formData.append("output_format", "jpeg");
  formData.append("output_compression", "92");
  formData.append("moderation", "auto");

  const response = await fetch("https://api.openai.com/v1/images/edits", {
    method: "POST",
    headers: {
      Authorization: `Bearer ${openAIApiKey}`,
    },
    body: formData,
  });

  const result = await parseImageResponse(response, "OpenAI");

  const imageBase64Response = result?.data?.[0]?.b64_json;

  if (!imageBase64Response) {
    throw new ResponseError("Image model returned an empty response.", 502);
  }

  return { imageBase64: imageBase64Response };
}

async function generateNanoBananaPreview(
  imageBase64: string,
  mimeType: string,
  prompt: string,
): Promise<ImageGenerationResult> {
  if (!geminiApiKey) {
    throw new Error("GEMINI_API_KEY or GOOGLE_API_KEY is not configured.");
  }

  const response = await fetch(
    `https://generativelanguage.googleapis.com/v1/models/${geminiImageModel}:generateContent`,
    {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "x-goog-api-key": geminiApiKey,
      },
      body: JSON.stringify({
        contents: [
          {
            role: "user",
            parts: [
              { text: prompt },
              {
                inline_data: {
                  mime_type: mimeType,
                  data: imageBase64,
                },
              },
            ],
          },
        ],
        generationConfig: {
          responseModalities: ["IMAGE"],
          responseFormat: {
            image: {
              aspectRatio: geminiAspectRatio,
              imageSize: geminiImageSize,
            },
          },
        },
      }),
    },
  );

  const result = await parseImageResponse(response, "Gemini");
  const parts = geminiParts(result);
  const imagePart = parts.find(
    (part) => part.inlineData?.data || part.inline_data?.data,
  );
  const imageBase64Response =
    imagePart?.inlineData?.data ?? imagePart?.inline_data?.data;

  if (!imageBase64Response) {
    const textResponse = parts
      .map((part) => part.text)
      .filter(Boolean)
      .join("\n")
      .trim();

    console.error("Gemini image generation returned no image", {
      finishReason: result?.candidates?.[0]?.finishReason,
      textResponse,
    });

    throw new ResponseError(
      textResponse || "Image model returned an empty response.",
      502,
    );
  }

  return { imageBase64: imageBase64Response };
}

async function parseImageResponse(response: Response, providerName: string) {
  const responseText = await response.text();
  let result;

  try {
    result = JSON.parse(responseText);
  } catch {
    result = {
      error: {
        message:
          responseText || `${providerName} returned a non-JSON response.`,
      },
    };
  }

  if (!response.ok) {
    console.error(`${providerName} image generation failed`, {
      status: response.status,
      error: result?.error?.message ?? result,
    });

    throw new ResponseError(
      result?.error?.message ?? "Unable to generate preview.",
      response.status,
    );
  }

  return result;
}

function geminiParts(result: {
  candidates?: Array<{ content?: { parts?: GeminiPart[] } }>;
}): GeminiPart[] {
  return (
    result?.candidates?.flatMap(
      (candidate) => candidate.content?.parts ?? [],
    ) ?? []
  );
}

class ResponseError extends Error {
  constructor(
    message: string,
    readonly status: number,
  ) {
    super(message);
  }
}

Deno.serve(async (request: Request) => {
  if (request.method !== "POST") {
    return jsonResponse({ error: "Method not allowed." }, 405);
  }

  let payload: BodyPreviewRequest;

  try {
    payload = await request.json();
  } catch {
    return jsonResponse({ error: "Invalid request body." }, 400);
  }

  const {
    imageBase64,
    mimeType = "image/jpeg",
    protocolName = "GLP-1",
  } = payload;

  if (!imageBase64) {
    return jsonResponse({ error: "Missing image." }, 400);
  }

  const imageBytes = decodeBase64Image(imageBase64);
  //   const prompt = `
  // Create a realistic health and fitness progress visualization of the same adult person in the uploaded reference photo.
  // Preserve identity, face, hair, skin tone, tattoos, pose, camera angle, lighting, framing, background, and current clothing coverage.
  // Keep the pose, expression, clothing, and framing neutral and modest. Do not make the image more revealing or suggestive.
  // Show a general ${protocolName} wellness preview with realistic, healthy-looking fitness progress. Emphasize a loss of body fat percentage.
  // Do not depict medical procedures, needles, scales, text, labels, before/after graphics, or guaranteed medication results.
  // This is only an illustrative wellness preview, not medical advice.
  // `.trim();

  const prompt = `
Create a future fitness transformation image of the same adult person from the uploaded reference photo.

Preserve the person’s identity, face, facial features, hair, haircut, skin tone, tattoos, pose, camera angle, lighting, framing, background, and clothing coverage. Keep all tattoos exactly the same: same placement, shape, size, and visibility. Do not add, remove, or alter tattoos. Do not change the haircut or hairstyle.

Transform only the person’s body composition to show a major but realistic reduction in body fat and body weight after 2 years of consistent diet, exercise, and medically supervised metabolic wellness treatment. The result should show aggressive visible fat loss while still looking natural and healthy.

The person should appear significantly leaner and more athletic: noticeably smaller waist and midsection, flatter stomach, reduced belly fat, reduced chest and back fat, slimmer arms, slimmer legs, more defined jawline, less facial puffiness, reduced neck fullness, improved posture, and a fitter overall body shape. Clothing should remain similar in coverage but should naturally fit the leaner body, with less tightness, less stretching, and more natural drape.

Do not preserve the original body size or silhouette. Do not keep the person overweight. The transformation should be clearly visible and substantial, not subtle.

Keep the image photorealistic and believable. The person should look healthier, leaner, more confident, and physically improved, without looking extreme, underweight, dehydrated, bodybuilder-like, or surgically altered.

Do not depict medical procedures, needles, syringes, pills, scales, doctors, clinics, text, labels, logos, before-and-after graphics, captions, measurement overlays, or guaranteed medication results.

`.trim();

  try {
    const result =
      imageProvider === "nano-banana-2"
        ? await generateNanoBananaPreview(imageBase64, mimeType, prompt)
        : await generateOpenAIPreview(imageBytes, mimeType, prompt);

    return jsonResponse({
      imageBase64: result.imageBase64,
      disclaimer:
        "Generated previews are illustrative only and are not medical advice or a promise of medication results.",
    });
  } catch (error) {
    const status = error instanceof ResponseError ? error.status : 500;
    const message =
      error instanceof Error ? error.message : "Unable to generate preview.";

    return jsonResponse({ error: message }, status);
  }
});
