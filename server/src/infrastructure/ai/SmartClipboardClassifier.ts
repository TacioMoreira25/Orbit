import { ClipboardContentType } from '../../core/entities/ClipboardItem.js';
import { ClassificationResult, ISmartClassifier } from '../../core/interfaces/ISmartClassifier.js';

export class SmartClipboardClassifier implements ISmartClassifier {
  async classify(content: string): Promise<ClassificationResult> {
    const trimmed = content.trim();

    // 1. Validação de URL
    if (this.isUrl(trimmed)) {
      return {
        type: 'url',
        formattedText: trimmed,
        confidence: 0.99,
      };
    }

    // 2. Validação de JSON estruturado
    if (this.isJson(trimmed)) {
      try {
        const parsed = JSON.parse(trimmed);
        const prettified = JSON.stringify(parsed, null, 2);
        return {
          type: 'json',
          detectedLanguage: 'json',
          formattedText: prettified,
          confidence: 0.95,
        };
      } catch {}
    }

    // 3. Validação de Código-Fonte (heurísticas léxicas)
    const codeAnalysis = this.analyzeCodePatterns(trimmed);
    if (codeAnalysis.isCode) {
      return {
        type: 'code',
        detectedLanguage: codeAnalysis.language,
        formattedText: trimmed,
        confidence: codeAnalysis.confidence,
      };
    }

    // 4. Validação de Markdown
    if (this.isMarkdown(trimmed)) {
      return {
        type: 'markdown',
        detectedLanguage: 'markdown',
        formattedText: trimmed,
        confidence: 0.85,
      };
    }

    // 5. Fallback: Texto Comum
    return {
      type: 'text',
      formattedText: content,
      confidence: 1.0,
    };
  }

  private isUrl(text: string): boolean {
    if (text.includes('\n')) return false;
    try {
      const url = new URL(text);
      return url.protocol === 'http:' || url.protocol === 'https:' || url.protocol === 'ftp:';
    } catch {
      return false;
    }
  }

  private isJson(text: string): boolean {
    if (!text.startsWith('{') && !text.startsWith('[')) return false;
    if (!text.endsWith('}') && !text.endsWith(']')) return false;
    try {
      JSON.parse(text);
      return true;
    } catch {
      return false;
    }
  }

  private isMarkdown(text: string): boolean {
    const mdPatterns = [
      /^#{1,6}\s+.+/m,              // Títulos # Header
      /^\s*[-*+]\s+.+/m,            // Listas com marcadores
      /^\s*\d+\.\s+.+/m,            // Listas numeradas
      /\[.+?\]\(https?:\/\/.+?\)/,   // Links Markdown [text](url)
      /`{3}[a-zA-Z]*\n[\s\S]*?`{3}/, // Fenced code blocks
      /\*\*([^*]+)\*\*/,            // Negrito
    ];

    let matches = 0;
    for (const pattern of mdPatterns) {
      if (pattern.test(text)) matches++;
    }

    return matches >= 2;
  }

  private analyzeCodePatterns(text: string): { isCode: boolean; language?: string; confidence: number } {
    // Padrões de código
    const patterns: Array<{ regex: RegExp; lang: string; weight: number }> = [
      { regex: /\b(import\s+.*from|export\s+(default|const|class|interface|type))\b/, lang: 'typescript', weight: 3 },
      { regex: /\b(const|let|var)\s+[a-zA-Z0-9_$]+\s*=\s*/, lang: 'javascript', weight: 2 },
      { regex: /\b(function\s+[a-zA-Z0-9_$]+\s*\(|=>\s*\{)/, lang: 'javascript', weight: 2 },
      { regex: /\b(def\s+[a-zA-Z0-9_]+\s*\(|elif\s+|if\s+__name__\s*==\s*['"]__main__['"])/, lang: 'python', weight: 3 },
      { regex: /\b(SELECT|INSERT\s+INTO|UPDATE|DELETE\s+FROM|WHERE|JOIN)\b/i, lang: 'sql', weight: 3 },
      { regex: /<\/?[a-z][a-z0-9]*(\s+[^>]+)?>/i, lang: 'html', weight: 2 },
      { regex: /\b(class\s+[A-Z][a-zA-Z0-9]*\s*(extends|implements|\{))/, lang: 'dart', weight: 2 },
      { regex: /^(curl|git|docker|npm|sudo|systemctl)\s+/m, lang: 'shell', weight: 2 },
    ];

    let totalScore = 0;
    let detectedLang: string | undefined;

    for (const item of patterns) {
      if (item.regex.test(text)) {
        totalScore += item.weight;
        detectedLang = item.lang;
      }
    }

    // Presença de delimitadores de chaves, ponto-e-vírgula e indentação típica
    if (text.includes(';') && (text.includes('{') && text.includes('}'))) {
      totalScore += 1;
    }

    return {
      isCode: totalScore >= 2,
      language: detectedLang,
      confidence: Math.min(0.9, totalScore * 0.25),
    };
  }
}
