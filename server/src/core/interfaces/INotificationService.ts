export interface INotificationService {
  notify(
    title: string,
    message: string,
    urgency?: 'low' | 'normal' | 'critical',
    actionOpenPath?: string
  ): Promise<void>;
}
