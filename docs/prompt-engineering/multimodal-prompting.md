---
id: multimodal-prompting
title: Multimodal prompting
sidebar_label: Multimodal prompting
---

# Multimodal prompting

Multimodal prompts combine text with images, video, audio, documents, or other files. Before designing one, verify that the selected model and provider support the required modalities, formats, size limits, ordering, and retention behavior. Provider details belong in that provider's documentation, not in a universal recipe.

## Make the evidence contract explicit

Name every supplied modality, state the task across them, and declare which source is authoritative when they conflict. Ask for observable evidence—such as a page, region, or timestamp—when it matters, and define fallback behavior for missing or contradictory inputs.

```text
Compare the invoice PDF with the call recording. The signed PDF is authoritative for totals.
For each discrepancy, cite the PDF page and the recording timestamp.
If either source is unreadable, return `needs_review` with the missing source.
```

All multimodal content is untrusted input. Images, files, and recordings can contain text or instructions intended to redirect the model; keep them as data and enforce permissions outside the prompt.

## Modality-specific details

- **Images:** check legibility, resolution, cropping, and orientation. Label and order multiple images explicitly.
- **Video:** request relevant time ranges or timestamps, segment long media, and distinguish visual evidence from spoken evidence.
- **Audio:** identify speakers and time windows; account for transcription uncertainty, language, noise, and overlap.
- **Documents/files:** use page or section anchors, select/chunk relevant content, account for tables and layout, and define an unsupported-format fallback.

## Evaluate the complete workflow

Test each modality alone and their combination, including corrupted, missing, and contradictory inputs. Verify that conflict and fallback behavior is observable rather than guessed. Where the product requires it, provide accessible alternate representations such as captions, transcripts, and text descriptions.
