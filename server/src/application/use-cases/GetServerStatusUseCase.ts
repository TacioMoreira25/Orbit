export interface ServerStatusOutput {
  status: 'online' | 'busy';
  serverName: string;
  version: string;
  activeConnections: number;
  uptimeSeconds: number;
  downloadDirectory: string;
}

export interface IStatusDataProvider {
  getActiveConnectionsCount(): number;
  getDownloadDirectory(): string;
  getServerName(): string;
}

export class GetServerStatusUseCase {
  private readonly startTime = Date.now();

  constructor(private readonly dataProvider: IStatusDataProvider) {}

  execute(): ServerStatusOutput {
    const uptimeSeconds = Math.floor((Date.now() - this.startTime) / 1000);

    return {
      status: 'online',
      serverName: this.dataProvider.getServerName(),
      version: '1.0.0',
      activeConnections: this.dataProvider.getActiveConnectionsCount(),
      uptimeSeconds,
      downloadDirectory: this.dataProvider.getDownloadDirectory(),
    };
  }
}
