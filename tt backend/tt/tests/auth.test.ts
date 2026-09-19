import { describe, it, expect } from 'vitest';
import { AuthService } from '../src/modules/auth/auth.service.js';

describe('AuthService Integration', () => {
  const testEmail = `guide-${Date.now()}@example.com`;
  const testPassword = 'Password123!';

  it('should register a new guide user with hashed password', async () => {
    const user = await AuthService.register({
      email: testEmail,
      password: testPassword,
      name: 'Sherpa Guide',
      phone: '+9779812345678',
      role: 'GUIDE',
    });

    expect(user).toBeDefined();
    expect(user.id).toBeDefined();
    expect(user.email).toBe(testEmail);
    expect(user.role).toBe('GUIDE');
    expect((user as any).password_hash).toBeUndefined(); // Ensure hash is not exposed
  });

  it('should prevent registration with duplicate email', async () => {
    await expect(
      AuthService.register({
        email: testEmail,
        password: 'AnotherPassword',
        name: 'Duplicate User',
      })
    ).rejects.toThrow();
  });

  it('should log in with valid credentials', async () => {
    const user = await AuthService.login({
      email: testEmail,
      password: testPassword,
    });

    expect(user).toBeDefined();
    expect(user.email).toBe(testEmail);
  });

  it('should reject login with wrong password', async () => {
    await expect(
      AuthService.login({
        email: testEmail,
        password: 'WrongPassword!',
      })
    ).rejects.toThrow(/Invalid email or password/);
  });
});
