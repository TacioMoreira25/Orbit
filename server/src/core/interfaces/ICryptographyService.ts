import { Transform } from 'node:stream';

export interface ICryptographyService {
  createSha256StreamTransformer(): {
    transform: Transform;
    getDigest: () => string;
  };
  generatePin(): string;
  generateToken(): string;
}
