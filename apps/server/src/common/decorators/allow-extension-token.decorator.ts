import { SetMetadata } from '@nestjs/common';

export const ALLOW_EXTENSION_TOKEN = 'allowExtensionToken';

/**
 * Marks a route as callable with a browser-extension token. Every other route
 * rejects extension tokens (403), so a leaked extension token cannot be used
 * to act as the user elsewhere.
 */
export const AllowExtensionToken = () => SetMetadata(ALLOW_EXTENSION_TOKEN, true);
