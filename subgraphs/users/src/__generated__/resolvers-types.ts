import { GraphQLResolveInfo } from 'graphql';
import { DataSourceContext } from '../types/DataSourceContext';
import { DeepPartial } from 'utility-types';
export type Maybe<T> = T | null;
export type InputMaybe<T> = Maybe<T>;
export type Exact<T extends { [key: string]: unknown }> = { [K in keyof T]: T[K] };
export type MakeOptional<T, K extends keyof T> = Omit<T, K> & { [SubKey in K]?: Maybe<T[SubKey]> };
export type MakeMaybe<T, K extends keyof T> = Omit<T, K> & { [SubKey in K]: Maybe<T[SubKey]> };
export type MakeEmpty<T extends { [key: string]: unknown }, K extends keyof T> = { [_ in K]?: never };
export type Incremental<T> = T | { [P in keyof T]?: P extends ' $fragmentName' | '__typename' ? T[P] : never };
export type RequireFields<T, K extends keyof T> = Omit<T, K> & { [P in K]-?: NonNullable<T[P]> };
/** All built-in and custom scalars, mapped to their actual values */
export type Scalars = {
  ID: { input: string; output: string; }
  String: { input: string; output: string; }
  Boolean: { input: boolean; output: boolean; }
  Int: { input: number; output: number; }
  Float: { input: number; output: number; }
  _FieldSet: { input: any; output: any; }
};

export type LoginFailed = {
  __typename?: 'LoginFailed';
  reason: Scalars['String']['output'];
};

export type LoginResponse = LoginFailed | LoginSuccessful;

export type LoginSuccessful = {
  __typename?: 'LoginSuccessful';
  scopes: Array<Scalars['String']['output']>;
  token: Scalars['String']['output'];
  user: User;
};

export type Mutation = {
  __typename?: 'Mutation';
  login?: Maybe<LoginResponse>;
};


export type MutationLoginArgs = {
  password: Scalars['String']['input'];
  scopes?: Array<Scalars['String']['input']>;
  username: Scalars['String']['input'];
};

export type Order = {
  __typename?: 'Order';
  id: Scalars['ID']['output'];
};

/** A saved payment option for an user */
export type PaymentMethod = {
  __typename?: 'PaymentMethod';
  description?: Maybe<Scalars['String']['output']>;
  id: Scalars['ID']['output'];
  name?: Maybe<Scalars['String']['output']>;
  type: PaymentType;
};

/** A fix set of payment types that we accept */
export enum PaymentType {
  BankAccount = 'BANK_ACCOUNT',
  CreditCard = 'CREDIT_CARD',
  DebitCard = 'DEBIT_CARD'
}

export type Query = {
  __typename?: 'Query';
  me?: Maybe<User>;
  /**
   * Get the current user from our fake "auth" headers
   * Set the "x-user-id" header to the user id.
   */
  user?: Maybe<User>;
};


export type QueryUserArgs = {
  id: Scalars['ID']['input'];
};

/** An user account in our system */
export type User = {
  __typename?: 'User';
  /** The user's email address */
  email?: Maybe<Scalars['String']['output']>;
  id: Scalars['ID']['output'];
  /** Total saved loyalty points and rewards */
  loyaltyPoints?: Maybe<Scalars['Int']['output']>;
  /** The users previous purchases */
  orders?: Maybe<Array<Maybe<Order>>>;
  /** Saved payment methods that can be used to submit orders */
  paymentMethods?: Maybe<Array<Maybe<PaymentMethod>>>;
  /** Get the list of last session id of user activity */
  previousSessions?: Maybe<Array<Scalars['ID']['output']>>;
  /** The users current saved shipping address */
  shippingAddress?: Maybe<Scalars['String']['output']>;
  /** The users login username */
  username: Scalars['String']['output'];
};

export type WithIndex<TObject> = TObject & Record<string, any>;
export type ResolversObject<TObject> = WithIndex<TObject>;

export type ResolverTypeWrapper<T> = Promise<T> | T;

export type ReferenceResolver<TResult, TReference, TContext> = (
      reference: TReference,
      context: TContext,
      info: GraphQLResolveInfo
    ) => Promise<TResult> | TResult;

      type ScalarCheck<T, S> = S extends true ? T : NullableCheck<T, S>;
      type NullableCheck<T, S> = Maybe<T> extends T ? Maybe<ListCheck<NonNullable<T>, S>> : ListCheck<T, S>;
      type ListCheck<T, S> = T extends (infer U)[] ? NullableCheck<U, S>[] : GraphQLRecursivePick<T, S>;
      export type GraphQLRecursivePick<T, S> = { [K in keyof T & keyof S]: ScalarCheck<T[K], S[K]> };
    

export type ResolverWithResolve<TResult, TParent, TContext, TArgs> = {
  resolve: ResolverFn<TResult, TParent, TContext, TArgs>;
};
export type Resolver<TResult, TParent = {}, TContext = {}, TArgs = {}> = ResolverFn<TResult, TParent, TContext, TArgs> | ResolverWithResolve<TResult, TParent, TContext, TArgs>;

export type ResolverFn<TResult, TParent, TContext, TArgs> = (
  parent: TParent,
  args: TArgs,
  context: TContext,
  info: GraphQLResolveInfo
) => Promise<TResult> | TResult;

export type SubscriptionSubscribeFn<TResult, TParent, TContext, TArgs> = (
  parent: TParent,
  args: TArgs,
  context: TContext,
  info: GraphQLResolveInfo
) => AsyncIterable<TResult> | Promise<AsyncIterable<TResult>>;

export type SubscriptionResolveFn<TResult, TParent, TContext, TArgs> = (
  parent: TParent,
  args: TArgs,
  context: TContext,
  info: GraphQLResolveInfo
) => TResult | Promise<TResult>;

export interface SubscriptionSubscriberObject<TResult, TKey extends string, TParent, TContext, TArgs> {
  subscribe: SubscriptionSubscribeFn<{ [key in TKey]: TResult }, TParent, TContext, TArgs>;
  resolve?: SubscriptionResolveFn<TResult, { [key in TKey]: TResult }, TContext, TArgs>;
}

export interface SubscriptionResolverObject<TResult, TParent, TContext, TArgs> {
  subscribe: SubscriptionSubscribeFn<any, TParent, TContext, TArgs>;
  resolve: SubscriptionResolveFn<TResult, any, TContext, TArgs>;
}

export type SubscriptionObject<TResult, TKey extends string, TParent, TContext, TArgs> =
  | SubscriptionSubscriberObject<TResult, TKey, TParent, TContext, TArgs>
  | SubscriptionResolverObject<TResult, TParent, TContext, TArgs>;

export type SubscriptionResolver<TResult, TKey extends string, TParent = {}, TContext = {}, TArgs = {}> =
  | ((...args: any[]) => SubscriptionObject<TResult, TKey, TParent, TContext, TArgs>)
  | SubscriptionObject<TResult, TKey, TParent, TContext, TArgs>;

export type TypeResolveFn<TTypes, TParent = {}, TContext = {}> = (
  parent: TParent,
  context: TContext,
  info: GraphQLResolveInfo
) => Maybe<TTypes> | Promise<Maybe<TTypes>>;

export type IsTypeOfResolverFn<T = {}, TContext = {}> = (obj: T, context: TContext, info: GraphQLResolveInfo) => boolean | Promise<boolean>;

export type NextResolverFn<T> = () => Promise<T>;

export type DirectiveResolverFn<TResult = {}, TParent = {}, TContext = {}, TArgs = {}> = (
  next: NextResolverFn<TResult>,
  parent: TParent,
  args: TArgs,
  context: TContext,
  info: GraphQLResolveInfo
) => TResult | Promise<TResult>;

/** Mapping of union types */
export type ResolversUnionTypes<_RefType extends Record<string, unknown>> = ResolversObject<{
  LoginResponse: ( DeepPartial<LoginFailed> ) | ( DeepPartial<LoginSuccessful> );
}>;


/** Mapping between all available schema types and the resolvers types */
export type ResolversTypes = ResolversObject<{
  LoginFailed: ResolverTypeWrapper<DeepPartial<LoginFailed>>;
  String: ResolverTypeWrapper<DeepPartial<Scalars['String']['output']>>;
  LoginResponse: DeepPartial<ResolverTypeWrapper<ResolversUnionTypes<ResolversTypes>['LoginResponse']>>;
  LoginSuccessful: ResolverTypeWrapper<DeepPartial<LoginSuccessful>>;
  Mutation: ResolverTypeWrapper<{}>;
  Order: ResolverTypeWrapper<DeepPartial<Order>>;
  ID: ResolverTypeWrapper<DeepPartial<Scalars['ID']['output']>>;
  PaymentMethod: ResolverTypeWrapper<DeepPartial<PaymentMethod>>;
  PaymentType: ResolverTypeWrapper<DeepPartial<PaymentType>>;
  Query: ResolverTypeWrapper<{}>;
  User: ResolverTypeWrapper<DeepPartial<User>>;
  Int: ResolverTypeWrapper<DeepPartial<Scalars['Int']['output']>>;
  Boolean: ResolverTypeWrapper<DeepPartial<Scalars['Boolean']['output']>>;
}>;

/** Mapping between all available schema types and the resolvers parents */
export type ResolversParentTypes = ResolversObject<{
  LoginFailed: DeepPartial<LoginFailed>;
  String: DeepPartial<Scalars['String']['output']>;
  LoginResponse: DeepPartial<ResolversUnionTypes<ResolversParentTypes>['LoginResponse']>;
  LoginSuccessful: DeepPartial<LoginSuccessful>;
  Mutation: {};
  Order: DeepPartial<Order>;
  ID: DeepPartial<Scalars['ID']['output']>;
  PaymentMethod: DeepPartial<PaymentMethod>;
  Query: {};
  User: DeepPartial<User>;
  Int: DeepPartial<Scalars['Int']['output']>;
  Boolean: DeepPartial<Scalars['Boolean']['output']>;
}>;

export type LoginFailedResolvers<ContextType = DataSourceContext, ParentType extends ResolversParentTypes['LoginFailed'] = ResolversParentTypes['LoginFailed']> = ResolversObject<{
  reason?: Resolver<ResolversTypes['String'], ParentType, ContextType>;
  __isTypeOf?: IsTypeOfResolverFn<ParentType, ContextType>;
}>;

export type LoginResponseResolvers<ContextType = DataSourceContext, ParentType extends ResolversParentTypes['LoginResponse'] = ResolversParentTypes['LoginResponse']> = ResolversObject<{
  __resolveType: TypeResolveFn<'LoginFailed' | 'LoginSuccessful', ParentType, ContextType>;
}>;

export type LoginSuccessfulResolvers<ContextType = DataSourceContext, ParentType extends ResolversParentTypes['LoginSuccessful'] = ResolversParentTypes['LoginSuccessful']> = ResolversObject<{
  scopes?: Resolver<Array<ResolversTypes['String']>, ParentType, ContextType>;
  token?: Resolver<ResolversTypes['String'], ParentType, ContextType>;
  user?: Resolver<ResolversTypes['User'], ParentType, ContextType>;
  __isTypeOf?: IsTypeOfResolverFn<ParentType, ContextType>;
}>;

export type MutationResolvers<ContextType = DataSourceContext, ParentType extends ResolversParentTypes['Mutation'] = ResolversParentTypes['Mutation']> = ResolversObject<{
  login?: Resolver<Maybe<ResolversTypes['LoginResponse']>, ParentType, ContextType, RequireFields<MutationLoginArgs, 'password' | 'scopes' | 'username'>>;
}>;

export type OrderResolvers<ContextType = DataSourceContext, ParentType extends ResolversParentTypes['Order'] = ResolversParentTypes['Order']> = ResolversObject<{
  __resolveReference?: ReferenceResolver<Maybe<ResolversTypes['Order']>, ParentType, ContextType>;
  id?: Resolver<ResolversTypes['ID'], ParentType, ContextType>;
  __isTypeOf?: IsTypeOfResolverFn<ParentType, ContextType>;
}>;

export type PaymentMethodResolvers<ContextType = DataSourceContext, ParentType extends ResolversParentTypes['PaymentMethod'] = ResolversParentTypes['PaymentMethod']> = ResolversObject<{
  description?: Resolver<Maybe<ResolversTypes['String']>, ParentType, ContextType>;
  id?: Resolver<ResolversTypes['ID'], ParentType, ContextType>;
  name?: Resolver<Maybe<ResolversTypes['String']>, ParentType, ContextType>;
  type?: Resolver<ResolversTypes['PaymentType'], ParentType, ContextType>;
  __isTypeOf?: IsTypeOfResolverFn<ParentType, ContextType>;
}>;

export type QueryResolvers<ContextType = DataSourceContext, ParentType extends ResolversParentTypes['Query'] = ResolversParentTypes['Query']> = ResolversObject<{
  me?: Resolver<Maybe<ResolversTypes['User']>, ParentType, ContextType>;
  user?: Resolver<Maybe<ResolversTypes['User']>, ParentType, ContextType, RequireFields<QueryUserArgs, 'id'>>;
}>;

export type UserResolvers<ContextType = DataSourceContext, ParentType extends ResolversParentTypes['User'] = ResolversParentTypes['User']> = ResolversObject<{
  __resolveReference?: ReferenceResolver<Maybe<ResolversTypes['User']>, { __typename: 'User' } & GraphQLRecursivePick<ParentType, {"id":true}>, ContextType>;
  email?: Resolver<Maybe<ResolversTypes['String']>, ParentType, ContextType>;
  id?: Resolver<ResolversTypes['ID'], ParentType, ContextType>;
  loyaltyPoints?: Resolver<Maybe<ResolversTypes['Int']>, ParentType, ContextType>;
  orders?: Resolver<Maybe<Array<Maybe<ResolversTypes['Order']>>>, ParentType, ContextType>;
  paymentMethods?: Resolver<Maybe<Array<Maybe<ResolversTypes['PaymentMethod']>>>, ParentType, ContextType>;
  previousSessions?: Resolver<Maybe<Array<ResolversTypes['ID']>>, ParentType, ContextType>;
  shippingAddress?: Resolver<Maybe<ResolversTypes['String']>, ParentType, ContextType>;
  username?: Resolver<ResolversTypes['String'], ParentType, ContextType>;
  __isTypeOf?: IsTypeOfResolverFn<ParentType, ContextType>;
}>;

export type Resolvers<ContextType = DataSourceContext> = ResolversObject<{
  LoginFailed?: LoginFailedResolvers<ContextType>;
  LoginResponse?: LoginResponseResolvers<ContextType>;
  LoginSuccessful?: LoginSuccessfulResolvers<ContextType>;
  Mutation?: MutationResolvers<ContextType>;
  Order?: OrderResolvers<ContextType>;
  PaymentMethod?: PaymentMethodResolvers<ContextType>;
  Query?: QueryResolvers<ContextType>;
  User?: UserResolvers<ContextType>;
}>;

