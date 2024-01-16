import { CodegenConfig } from "@graphql-codegen/cli";

const config: CodegenConfig = {
  schema: "./*.graphql",
  generates: {
    "./src/__generated__/resolvers-types.ts": {
      config: {
        federation: true,
        useIndexSignature: true,
                contextType: "../types/DataSourceContext#DataSourceContext",
        defaultMapper: "DeepPartial<{T}>",
        
      },
      plugins: ["typescript","typescript-resolvers", { add: { content: "import { DeepPartial } from 'utility-types';" } },]
    },
  },
};

export default config;
