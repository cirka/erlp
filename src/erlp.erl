-module(erlp).

%% API exports
-export([
    hex_to_bin/1,
    bin_to_hex/1,
    bin_to_int/1,
    int_to_bin/1,
    decode/1,
    encode/1]).

-type rlp() :: binary().
-type item() :: binary().
-type item_list() :: list(item_list | item()).

%%====================================================================
%% API functions
%%====================================================================
hex_to_bin(List) when is_list(List) andalso length(List) rem 2 == 0 ->
 hex_to_bin(List, []);
hex_to_bin(_) -> error(badarg).

bin_to_hex(Bin) -> bin_to_hex(Bin, "x0").

bin_to_int(<<>>) -> 0;
bin_to_int(Bin) ->
 Size = size(Bin),
 << Int:Size/big-unsigned-unit:8>> = Bin,
 Int.

int_to_bin(Int) -> binary:encode_unsigned(Int, big).

-spec decode(rlp()) -> item_list().
decode(Bin) -> {RLP, <<>>} = decode_item(Bin), RLP.

-spec encode(item_list()) -> rlp().
encode(RLP) -> encode_item(RLP).

%%====================================================================
%% Internal functions
%%====================================================================

hex_to_bin([$0,$x|Rest], Acc) -> hex_to_bin(Rest, Acc);
hex_to_bin([E1,E2|Rest], Acc) -> hex_to_bin(Rest, [[list_to_integer([E1, E2], 16)]| Acc]);
hex_to_bin([], Acc) -> list_to_binary(lists:reverse(Acc)).


bin_to_hex(<<>>, Acc) -> lists:reverse(Acc);
bin_to_hex(<<A:4, B:4, Rest/binary>>, Acc) -> bin_to_hex(Rest, [nibble_to_hex(B), nibble_to_hex(A) | Acc]).


nibble_to_hex(X) when X < 10 -> $0 + X;
nibble_to_hex(X) when X >= 10 andalso X <16 -> $a + X - 10;
nibble_to_hex(X) -> error(badarg).


encode_item(List) when is_list(List) -> encode_list(List);

encode_item(<<SmallBin/integer>> = Bin) when SmallBin =< 16#7f -> Bin;

encode_item(Bin) ->
 case size(Bin) of
  Size when Size =< 55 -> <<(16#80 + Size)/integer, Bin/binary>>;
  Size ->
    SizeBin = binary:encode_unsigned(Size, big),
    SizeLen = size(SizeBin),
   << (16#b7 + SizeLen)/integer, SizeBin/binary, Bin/binary >>
 end.

encode_list(Items) -> encode_list(Items, []).

encode_list([], Bins) ->
 OneBin = list_to_binary(lists:reverse(Bins)),
 case size(OneBin) of
   Size when Size =<55 -> << (16#c0 + Size)/integer, OneBin/binary>>;
   Size ->
    SizeBin = binary:encode_unsigned(Size, big),
    SizeLen = size(SizeBin),
    << (16#f7 + SizeLen)/integer, SizeBin/binary, OneBin/binary >>
 end;

encode_list([Item|Items], Bins) ->
 Bin = encode_item(Item),
 encode_list(Items, [Bin|Bins]).


decode_item(<<F:1/unsigned-integer-unit:8, Rest/binary>>) when F =< 16#7f ->
 {<<F/integer>>, Rest};

decode_item(<<F:1/unsigned-integer-unit:8, Rest/binary>>) when F =< 16#b7 ->
 Length = F - 16#80,
 <<Res:Length/binary, Rest1/binary >> = Rest,
 {Res, Rest1};

decode_item(<<F:1/unsigned-integer-unit:8, Rest/binary>>) when F =< 16#bf ->
 LengthBytes = F - 16#b7,
 <<Length:LengthBytes/big-unsigned-integer-unit:8, Rest1/binary>> = Rest,
 <<Res:Length/bytes, Rest2/binary >> = Rest1,
 {Res, Rest2};

decode_item(<<F:1/unsigned-integer-unit:8, Rest/binary>>) when F =< 16#f7 ->
 Length = F - 16#c0,
 <<List:Length/bytes, Rest1/binary >> = Rest,
 Res = decode_list(List),
 {Res, Rest1};

decode_item(<<F:1/unsigned-integer-unit:8, Rest/binary>>) -> % when 16#f7 < F =< 16#ff
 LengthBytes = F - 16#f7,
 <<Length:LengthBytes/big-unsigned-integer-unit:8, Rest1/binary>> = Rest,
 <<List:Length/bytes, Rest2/binary >> = Rest1,
 Res = decode_list(List),
 {Res, Rest2}.


decode_list(Bin) -> decode_list(Bin, []).

decode_list(<<>>, Acc) -> lists:reverse(Acc);

decode_list(Bin, Acc) -> 
 {Item, Rest} = decode_item(Bin),
 decode_list(Rest, [Item |Acc]).

