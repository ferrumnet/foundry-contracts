import { SecretsManagerClient, GetSecretValueCommand } from "@aws-sdk/client-secrets-manager";

export class Secrets {
  public static async fromAws(arn?: string): Promise<any> {
    const client = new SecretsManagerClient({
      region: process.env.AWS_REGION || 'us-east-2',
    });
    const SecretId = arn || process.env.PAIVATE_KEY_SECRET_ARN;
    if (!SecretId) {
      throw new Error('SecretId is required. Pass it or set PAIVATE_KEY_SECRET_ARN env variable');
    }
    const command = new GetSecretValueCommand({ SecretId });
    const response = await client.send(command);

    if (response.SecretString) {
      return JSON.parse(response.SecretString);
    } else if (response.SecretBinary) {
      // If the secret is stored as binary data
      return JSON.parse(Buffer.from(response.SecretBinary as any, 'base64').toString('utf-8'));
    }
  } catch (error) {
    console.error("Error retrieving secret:", error);
    throw error;
  }
}