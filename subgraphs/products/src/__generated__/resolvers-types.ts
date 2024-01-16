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

/**
 * A specific product sold by our store. This contains all the high level details but is not the purchasable item.
 * See Variant for more info.
 */
export type Product = {
  __typename?: 'Product';
  description?: Maybe<Scalars['String']['output']>;
  id: Scalars['ID']['output'];
  mediaUrl?: Maybe<Scalars['String']['output']>;
  /** Mock random date of when a product might be released */
  releaseDate?: Maybe<Scalars['String']['output']>;
  title?: Maybe<Scalars['String']['output']>;
  upc: Scalars['ID']['output'];
  /** Variants of the products to view specific size/color/price options */
  variants?: Maybe<Array<Maybe<Variant>>>;
};


/**
 * A specific product sold by our store. This contains all the high level details but is not the purchasable item.
 * See Variant for more info.
 */
export type ProductVariantsArgs = {
  searchInput?: InputMaybe<VariantSearchInput>;
};

/** Search filters for when returning Products */
export type ProductSearchInput = {
  titleStartsWith?: InputMaybe<Scalars['String']['input']>;
};

export type Query = {
  __typename?: 'Query';
  /** Get a specific product by id. Useful for the product details page or checkout page */
  product?: Maybe<Product>;
  /** Get all available products to shop for. Optionally provide some search filters */
  searchProducts?: Maybe<Array<Maybe<Product>>>;
  /** Get all available variants of products to shop for. Optionally provide some search filters */
  searchVariants?: Maybe<Array<Maybe<Variant>>>;
  /** Get a specific variant by id. Useful for the product details page or checkout page */
  variant?: Maybe<Variant>;
};


export type QueryProductArgs = {
  id: Scalars['ID']['input'];
};


export type QuerySearchProductsArgs = {
  searchInput?: ProductSearchInput;
};


export type QuerySearchVariantsArgs = {
  searchInput?: VariantSearchInput;
};


export type QueryVariantArgs = {
  id: Scalars['ID']['input'];
};

/**
 * A variant of a product which is a unique combination of attributes like size and color
 * Variants are the entities that are added to carts and purchased
 */
export type Variant = {
  __typename?: 'Variant';
  /** Optional color option for this variant */
  colorway?: Maybe<Scalars['String']['output']>;
  /** Optional dimensions. Can be use to calculate other info like shipping or packaging */
  dimensions?: Maybe<Scalars['String']['output']>;
  id: Scalars['ID']['output'];
  /** Price in decimals for this variant */
  price: Scalars['Float']['output'];
  /** Link back to the parent Product */
  product?: Maybe<Product>;
  /** Optional size option for this variant */
  size?: Maybe<Scalars['String']['output']>;
  /** Optional weight. Can be use to calculate other info like shipping or packaging */
  weight?: Maybe<Scalars['Float']['output']>;
};

/** Search filters for when returning Variants */
export type VariantSearchInput = {
  sizeStartsWith?: InputMaybe<Scalars['String']['input']>;
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
  Product: ResolverTypeWrapper<DeepPartial<Product>>;
  String: ResolverTypeWrapper<DeepPartial<Scalars['String']['output']>>;
  ID: ResolverTypeWrapper<DeepPartial<Scalars['ID']['output']>>;
  ProductSearchInput: ResolverTypeWrapper<DeepPartial<ProductSearchInput>>;
  Query: ResolverTypeWrapper<{}>;
  Variant: ResolverTypeWrapper<DeepPartial<Variant>>;
  Float: ResolverTypeWrapper<DeepPartial<Scalars['Float']['output']>>;
  VariantSearchInput: ResolverTypeWrapper<DeepPartial<VariantSearchInput>>;
  Boolean: ResolverTypeWrapper<DeepPartial<Scalars['Boolean']['output']>>;
}>;

/** Mapping between all available schema types and the resolvers parents */
export type ResolversParentTypes = ResolversObject<{
  Product: DeepPartial<Product>;
  String: DeepPartial<Scalars['String']['output']>;
  ID: DeepPartial<Scalars['ID']['output']>;
  ProductSearchInput: DeepPartial<ProductSearchInput>;
  Query: {};
  Variant: DeepPartial<Variant>;
  Float: DeepPartial<Scalars['Float']['output']>;
  VariantSearchInput: DeepPartial<VariantSearchInput>;
  Boolean: DeepPartial<Scalars['Boolean']['output']>;
}>;

export type ProductResolvers<ContextType = DataSourceContext, ParentType extends ResolversParentTypes['Product'] = ResolversParentTypes['Product']> = ResolversObject<{
  __resolveReference?: ReferenceResolver<Maybe<ResolversTypes['Product']>, { __typename: 'Product' } & (GraphQLRecursivePick<ParentType, {"id":true}> | GraphQLRecursivePick<ParentType, {"upc":true}>), ContextType>;
  description?: Resolver<Maybe<ResolversTypes['String']>, ParentType, ContextType>;
  id?: Resolver<ResolversTypes['ID'], ParentType, ContextType>;
  mediaUrl?: Resolver<Maybe<ResolversTypes['String']>, ParentType, ContextType>;
  releaseDate?: Resolver<Maybe<ResolversTypes['String']>, ParentType, ContextType>;
  title?: Resolver<Maybe<ResolversTypes['String']>, ParentType, ContextType>;
  upc?: Resolver<ResolversTypes['ID'], ParentType, ContextType>;
  variants?: Resolver<Maybe<Array<Maybe<ResolversTypes['Variant']>>>, ParentType, ContextType, RequireFields<ProductVariantsArgs, 'searchInput'>>;
  __isTypeOf?: IsTypeOfResolverFn<ParentType, ContextType>;
}>;

export type QueryResolvers<ContextType = DataSourceContext, ParentType extends ResolversParentTypes['Query'] = ResolversParentTypes['Query']> = ResolversObject<{
  product?: Resolver<Maybe<ResolversTypes['Product']>, ParentType, ContextType, RequireFields<QueryProductArgs, 'id'>>;
  searchProducts?: Resolver<Maybe<Array<Maybe<ResolversTypes['Product']>>>, ParentType, ContextType, RequireFields<QuerySearchProductsArgs, 'searchInput'>>;
  searchVariants?: Resolver<Maybe<Array<Maybe<ResolversTypes['Variant']>>>, ParentType, ContextType, RequireFields<QuerySearchVariantsArgs, 'searchInput'>>;
  variant?: Resolver<Maybe<ResolversTypes['Variant']>, ParentType, ContextType, RequireFields<QueryVariantArgs, 'id'>>;
}>;

export type VariantResolvers<ContextType = DataSourceContext, ParentType extends ResolversParentTypes['Variant'] = ResolversParentTypes['Variant']> = ResolversObject<{
  __resolveReference?: ReferenceResolver<Maybe<ResolversTypes['Variant']>, { __typename: 'Variant' } & GraphQLRecursivePick<ParentType, {"id":true}>, ContextType>;
  colorway?: Resolver<Maybe<ResolversTypes['String']>, ParentType, ContextType>;
  dimensions?: Resolver<Maybe<ResolversTypes['String']>, ParentType, ContextType>;
  id?: Resolver<ResolversTypes['ID'], ParentType, ContextType>;
  price?: Resolver<ResolversTypes['Float'], ParentType, ContextType>;
  product?: Resolver<Maybe<ResolversTypes['Product']>, ParentType, ContextType>;
  size?: Resolver<Maybe<ResolversTypes['String']>, ParentType, ContextType>;
  weight?: Resolver<Maybe<ResolversTypes['Float']>, ParentType, ContextType>;
  __isTypeOf?: IsTypeOfResolverFn<ParentType, ContextType>;
}>;

export type Resolvers<ContextType = DataSourceContext> = ResolversObject<{
  Product?: ProductResolvers<ContextType>;
  Query?: QueryResolvers<ContextType>;
  Variant?: VariantResolvers<ContextType>;
}>;

