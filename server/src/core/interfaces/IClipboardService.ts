export interface IClipboardService {
  writeText(text: string): Promise<boolean>;
  readText(): Promise<string>;
}
