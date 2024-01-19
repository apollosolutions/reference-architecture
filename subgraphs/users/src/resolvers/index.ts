import { DataUserType, users } from "./data.js";
import { GraphQLError } from "graphql";
import { v4 as uuidv4 } from "uuid";
import { readFile } from "fs/promises";
import { createPrivateKey } from "crypto";
import * as jose from 'jose'
import { PaymentType, Resolvers, User } from "../__generated__/resolvers-types.js";

const getUserById = (id: string) => convertUser(users.find((it: DataUserType) => it.id === id));
const getUserbyUsername = (username: string) => users.find((u) => u.username === username);
const convertUser = (user: DataUserType): User => {
  return {
    ...user,
    paymentMethods: user.paymentMethods.map((pm) => ({
      __typename: 'PaymentMethod',
      ...pm,
      type: pm.type as PaymentType
    })),
  }
}

export const resolvers: Resolvers = {
  LoginResponse: {
    __resolveType(parent) {
      //@ts-ignore
      if (parent.reason) {
        return 'LoginFailed'
      } else {
        return 'LoginSuccessful'
      }
    }
  },
  Query: {
    user(_, { id }, { user: payload }) {
      const user = getUserById(id);

      if (!user) {
        throw new GraphQLError("Could not locate user by provided id");
      }
      const userScopes = payload?.scope.split(' ') ?? []

      if (payload && payload.sub !== user.id && !userScopes.includes('user:read:email')) {
        delete user.email
      }

      return user;
    },
    me: (_, __, { user }) => user ? getUserById(user.sub) : null
  },
  Mutation: {
    async login(_, { username, password, scopes }) {
      let user = getUserbyUsername(username)
      if (!user || password === "") {
        return {
          reason: "user not found"
        }
      }
      const privateKeyText = await readFile("./keys/private_key.pem", {
        encoding: "utf8"
      });

      const alg = "ES256";
      const privateKey = createPrivateKey(privateKeyText);
      const token = await new jose.SignJWT({
        sub: user.id,
        scope: scopes.join(' '),
        username,
      }).setProtectedHeader({ alg }).setIssuedAt().setExpirationTime('2h').sign(privateKey);

      return {
        token,
        user,
        scopes
      }
    }
  },
  User: {
    __resolveReference(ref) {
      return getUserById(ref.id);
    },
    previousSessions: () => [uuidv4(), uuidv4()],
    loyaltyPoints: () => Math.floor(Math.random() * 20)
  },
};
