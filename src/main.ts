import { NestFactory } from '@nestjs/core';
import { AppModule } from './app.module';

async function bootstrap() {
  const app = await NestFactory.create(AppModule, { cors: true });
  const port = process.env.PORT || 3000;
  await app.listen(process.env.PORT || 3000, '0.0.0.0');
  console.log(`API → http://localhost:${port}`);
}
bootstrap();
