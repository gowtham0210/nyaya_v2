import type { Role } from '../db/schema.js';

/** The signed-in user, loaded fresh from the database on every request. */
export interface AuthUser {
  id: string;
  email: string;
  displayName: string;
  roles: Role[];
}
