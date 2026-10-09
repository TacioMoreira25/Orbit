import { z } from 'zod';

export const PairRequestSchema = z.object({
  pin: z.string().length(4, 'O PIN deve conter exatamente 4 dígitos'),
  deviceName: z.string().min(1, 'Nome do dispositivo é obrigatório'),
  platform: z.enum(['android', 'linux', 'ios', 'windows', 'macos']).default('android'),
});

export const ClipboardSyncSchema = z.object({
  content: z.string().min(1, 'Conteúdo da área de transferência não pode estar vazio'),
  senderDeviceId: z.string().optional().default('unknown-device'),
});

export type PairRequestDto = z.infer<typeof PairRequestSchema>;
export type ClipboardSyncDto = z.infer<typeof ClipboardSyncSchema>;
