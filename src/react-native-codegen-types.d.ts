declare module 'react-native/Libraries/Types/CodegenTypes' {
  export type Double = number;
  export type Int32 = number;
  export type DirectEventHandler<T> = (event: {
    nativeEvent: T;
  }) => void | Promise<void>;
}
