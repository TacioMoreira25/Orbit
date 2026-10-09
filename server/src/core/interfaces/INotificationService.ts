export interface INotificationService {
  notify(title: string, message: string, urgency?: 'low' | 'normal' | 'critical'): Promise<void>;
}
