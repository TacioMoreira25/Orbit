import crypto from 'node:crypto';
import { Transform } from 'node:stream';
import { ICryptographyService } from '../../core/interfaces/ICryptographyService.js';

export class Sha256StreamValidator implements ICryptographyService {
  createSha256StreamTransformer(): { transform: Transform; getDigest: () => string } {
    const hash = crypto.createHash('sha256');

    const transform = new Transform({
      transform(chunk, _encoding, callback) {
        hash.update(chunk);
        callback(null, chunk);
      },
    });

    return {
      transform,
      getDigest: () => hash.digest('hex'),
    };
  }

  generatePin(): string {
    // Gera PIN numérico seguro de 4 dígitos (1000 - 9999)
    return crypto.randomInt(1000, 10000).toString();
  }

  generateToken(): string {
    return crypto.randomBytes(32).toString('hex');
  }
}
