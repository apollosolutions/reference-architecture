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

/** An user's saved cart session. Only one cart can be active at a time */
export type Cart = {
  __typename?: 'Cart';
  /** Items saved in the cart session */
  items?: Maybe<Array<Maybe<Variant>>>;
  /** The current total of all the items in the cart, before taxes and shipping */
  subtotal?: Maybe<Scalars['Float']['output']>;
  /** Each user can only have one cart so the ID is the same as the user ID */
  userId: Scalars['ID']['output'];
};

export type CartMutations = {
  __typename?: 'CartMutations';
  addVariantToCart?: Maybe<ResultWithMessage>;
  checkout?: Maybe<CheckoutResult>;
  removeVariantFromCart?: Maybe<ResultWithMessage>;
};


export type CartMutationsAddVariantToCartArgs = {
  quantity?: InputMaybe<Scalars['Int']['input']>;
  variantId: Scalars['ID']['input'];
};


export type CartMutationsCheckoutArgs = {
  paymentMethodId: Scalars['ID']['input'];
};


export type CartMutationsRemoveVariantFromCartArgs = {
  quantity?: InputMaybe<Scalars['Int']['input']>;
  variantId: Scalars['ID']['input'];
};

export type CheckoutResult = {
  __typename?: 'CheckoutResult';
  orderID?: Maybe<Scalars['ID']['output']>;
  successful?: Maybe<Scalars['Boolean']['output']>;
};

export type Mutation = {
  __typename?: 'Mutation';
  cart?: Maybe<CartMutations>;
};

export type ResultWithMessage = {
  __typename?: 'ResultWithMessage';
  message?: Maybe<Scalars['String']['output']>;
  successful?: Maybe<Scalars['Boolean']['output']>;
};

export type User = {
  __typename?: 'User';
  /** The user's active cart session. Once the cart items have been purchases, they transition to an Order */
  cart?: Maybe<Cart>;
  id: Scalars['ID']['output'];
};

export type Variant = {
  __typename?: 'Variant';
  id: Scalars['ID']['output'];
  price: Scalars['Float']['output'];
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



/** Mapping between all available schema types and the resolvers types */
export type ResolversTypes = ResolversObject<{
  Cart: ResolverTypeWrapper<DeepPartial<Cart>>;
  Float: ResolverTypeWrapper<DeepPartial<Scalars['Float']['output']>>;
  ID: ResolverTypeWrapper<DeepPartial<Scalars['ID']['output']>>;
  CartMutations: ResolverTypeWrapper<DeepPartial<CartMutations>>;
  Int: ResolverTypeWrapper<DeepPartial<Scalars['Int']['output']>>;
  CheckoutResult: ResolverTypeWrapper<DeepPartial<CheckoutResult>>;
  Boolean: ResolverTypeWrapper<DeepPartial<Scalars['Boolean']['output']>>;
  Mutation: ResolverTypeWrapper<{}>;
  ResultWithMessage: ResolverTypeWrapper<DeepPartial<ResultWithMessage>>;
  String: ResolverTypeWrapper<DeepPartial<Scalars['String']['output']>>;
  User: ResolverTypeWrapper<DeepPartial<User>>;
  Variant: ResolverTypeWrapper<DeepPartial<Variant>>;
}>;

/** Mapping between all available schema types and the resolvers parents */
export type ResolversParentTypes = ResolversObject<{
  Cart: DeepPartial<Cart>;
  Float: DeepPartial<Scalars['Float']['output']>;
  ID: DeepPartial<Scalars['ID']['output']>;
  CartMutations: DeepPartial<CartMutations>;
  Int: DeepPartial<Scalars['Int']['output']>;
  CheckoutResult: DeepPartial<CheckoutResult>;
  Boolean: DeepPartial<Scalars['Boolean']['output']>;
  Mutation: {};
  ResultWithMessage: DeepPartial<ResultWithMessage>;
  String: DeepPartial<Scalars['String']['output']>;
  User: DeepPartial<User>;
  Variant: DeepPartial<Variant>;
}>;

export type CartResolvers<ContextType = DataSourceContext, ParentType extends ResolversParentTypes['Cart'] = ResolversParentTypes['Cart']> = ResolversObject<{
  __resolveReference?: ReferenceResolver<Maybe<ResolversTypes['Cart']>, { __typename: 'Cart' } & GraphQLRecursivePick<ParentType, {"userId":true}>, ContextType>;
  items?: Resolver<Maybe<Array<Maybe<ResolversTypes['Variant']>>>, ParentType, ContextType>;
  subtotal?: Resolver<Maybe<ResolversTypes['Float']>, ParentType, ContextType>;
  userId?: Resolver<ResolversTypes['ID'], ParentType, ContextType>;
  __isTypeOf?: IsTypeOfResolverFn<ParentType, ContextType>;
}>;

export type CartMutationsResolvers<ContextType = DataSourceContext, ParentType extends ResolversParentTypes['CartMutations'] = ResolversParentTypes['CartMutations']> = ResolversObject<{
  addVariantToCart?: Resolver<Maybe<ResolversTypes['ResultWithMessage']>, ParentType, ContextType, RequireFields<CartMutationsAddVariantToCartArgs, 'quantity' | 'variantId'>>;
  checkout?: Resolver<Maybe<ResolversTypes['CheckoutResult']>, ParentType, ContextType, RequireFields<CartMutationsCheckoutArgs, 'paymentMethodId'>>;
  removeVariantFromCart?: Resolver<Maybe<ResolversTypes['ResultWithMessage']>, ParentType, ContextType, RequireFields<CartMutationsRemoveVariantFromCartArgs, 'quantity' | 'variantId'>>;
  __isTypeOf?: IsTypeOfResolverFn<ParentType, ContextType>;
}>;

export type CheckoutResultResolvers<ContextType = DataSourceContext, ParentType extends ResolversParentTypes['CheckoutResult'] = ResolversParentTypes['CheckoutResult']> = ResolversObject<{
  orderID?: Resolver<Maybe<ResolversTypes['ID']>, ParentType, ContextType>;
  successful?: Resolver<Maybe<ResolversTypes['Boolean']>, ParentType, ContextType>;
  __isTypeOf?: IsTypeOfResolverFn<ParentType, ContextType>;
}>;

export type MutationResolvers<ContextType = DataSourceContext, ParentType extends ResolversParentTypes['Mutation'] = ResolversParentTypes['Mutation']> = ResolversObject<{
  cart?: Resolver<Maybe<ResolversTypes['CartMutations']>, ParentType, ContextType>;
}>;

export type ResultWithMessageResolvers<ContextType = DataSourceContext, ParentType extends ResolversParentTypes['ResultWithMessage'] = ResolversParentTypes['ResultWithMessage']> = ResolversObject<{
  message?: Resolver<Maybe<ResolversTypes['String']>, ParentType, ContextType>;
  successful?: Resolver<Maybe<ResolversTypes['Boolean']>, ParentType, ContextType>;
  __isTypeOf?: IsTypeOfResolverFn<ParentType, ContextType>;
}>;

export type UserResolvers<ContextType = DataSourceContext, ParentType extends ResolversParentTypes['User'] = ResolversParentTypes['User']> = ResolversObject<{
  __resolveReference?: ReferenceResolver<Maybe<ResolversTypes['User']>, { __typename: 'User' } & GraphQLRecursivePick<ParentType, {"id":true}>, ContextType>;
  cart?: Resolver<Maybe<ResolversTypes['Cart']>, ParentType, ContextType>;
  id?: Resolver<ResolversTypes['ID'], ParentType, ContextType>;
  __isTypeOf?: IsTypeOfResolverFn<ParentType, ContextType>;
}>;

export type VariantResolvers<ContextType = DataSourceContext, ParentType extends ResolversParentTypes['Variant'] = ResolversParentTypes['Variant']> = ResolversObject<{
  __resolveReference?: ReferenceResolver<Maybe<ResolversTypes['Variant']>, { __typename: 'Variant' } & GraphQLRecursivePick<ParentType, {"id":true}>, ContextType>;
  id?: Resolver<ResolversTypes['ID'], { __typename: 'Variant' } & GraphQLRecursivePick<ParentType, {"id":true}>, ContextType>;

  __isTypeOf?: IsTypeOfResolverFn<ParentType, ContextType>;
}>;

export type Resolvers<ContextType = DataSourceContext> = ResolversObject<{
  Cart?: CartResolvers<ContextType>;
  CartMutations?: CartMutationsResolvers<ContextType>;
  CheckoutResult?: CheckoutResultResolvers<ContextType>;
  Mutation?: MutationResolvers<ContextType>;
  ResultWithMessage?: ResultWithMessageResolvers<ContextType>;
  User?: UserResolvers<ContextType>;
  Variant?: VariantResolvers<ContextType>;
}>;

