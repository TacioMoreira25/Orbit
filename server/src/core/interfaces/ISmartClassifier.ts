import { ClipboardContentType } from '../entities/ClipboardItem.js';

export interface ClassificationResult {
  type: ClipboardContentType;
  detectedLanguage?: string;
  formattedText: string;
  confidence: number;
}

export interface ISmartClassifier {
  classify(content: string): Promise<ClassificationResult>;
}
