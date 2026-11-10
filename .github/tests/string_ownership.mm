// The SDK implementation is linked unchanged; only the 4D engine is simulated.
#include "../../4DPlugin.cpp"
#include "PrivateTypes.h"
#include "EntryPoints.h"
#include <cassert>
#include <cstdlib>
#include <cstring>
#include <iostream>
#include <set>

static bool allocatedEmpty;
static std::set<PA_Unichar *> strings;
static std::map<PA_Handle, size_t> handles;
static CUTF16String expected;
static int returnKind;
static int calls;

static PA_Unistring makeString(const PA_Unichar *text)
{
    PA_Unistring value = {};
    while (text && text[value.fLength]) ++value.fLength;
    if (value.fLength || allocatedEmpty)
    {
        value.fString = new PA_Unichar[value.fLength + 1]();
        if (value.fLength)
            memcpy(value.fString, text, value.fLength * sizeof(PA_Unichar));
        assert(strings.insert(static_cast<PA_Unichar *>(value.fString)).second);
    }
    return value;
}

static void dispose(PA_Unistring &value)
{
    if (value.fString)
    {
        assert(strings.erase(static_cast<PA_Unichar *>(value.fString)) == 1 && "double disposal or borrowed string");
        delete[] value.fString;
    }
    value = {};
}

static void check(const PA_Unistring &value)
{
    assert(value.fLength == expected.size());
    if (value.fString)
    {
        assert(strings.count(static_cast<PA_Unichar *>(value.fString)));
        assert(CUTF16String(value.fString, value.fLength) == expected);
        assert(value.fString[value.fLength] == 0);
    }
    else assert(expected.empty());
}

static void clear(PA_Variable &value)
{
    if (value.fType == eVK_Unistring) dispose(value.uValue.fString);
    else if (value.fType == eVK_ArrayUnicode)
    {
        auto elements = reinterpret_cast<PA_Unistring *>(*value.uValue.fArray.fData);
        for (int i = 0; i <= value.uValue.fArray.fNbElements; ++i) dispose(elements[i]);
        PA_DisposeHandle(value.uValue.fArray.fData);
    }
    value = {};
}

static void host(short selector, EngineBlock *eb)
{
    switch (selector)
    {
        case EX_CREATE_UNISTRING:
            eb->fUniString1 = makeString(reinterpret_cast<PA_Unichar *>(eb->fHandle));
            break;
        case EX_DISPOSE_UNISTRING:
            dispose(eb->fUniString1);
            break;
        case EX_SET_UNISTRING:
        {
            auto replacement = makeString(reinterpret_cast<PA_Unichar *>(eb->fHandle));
            dispose(eb->fUniString1);
            eb->fUniString1 = replacement;
            break;
        }
        case EX_CLEAR_VARIABLE:
            clear(*static_cast<PA_Variable *>(eb->fPtr1));
            break;
        case EX_HANDLE_MANAGER:
            eb->fError = 0;
            switch (eb->fParam1)
            {
                case 1:
                    eb->fHandle = new char *;
                    *eb->fHandle = static_cast<char *>(calloc(1, eb->fParam2));
                    handles[static_cast<PA_Handle>(eb->fHandle)] = eb->fParam2;
                    break;
                case 2:
                    assert(handles.erase(static_cast<PA_Handle>(eb->fHandle)) == 1);
                    free(*eb->fHandle);
                    delete eb->fHandle;
                    break;
                case 3:
                    assert(handles.count(static_cast<PA_Handle>(eb->fHandle)));
                    *eb->fHandle = static_cast<char *>(realloc(*eb->fHandle, eb->fParam2));
                    handles[static_cast<PA_Handle>(eb->fHandle)] = eb->fParam2;
                    break;
                case 4:
                    eb->fParam2 = handles.at(static_cast<PA_Handle>(eb->fHandle));
                    break;
                case 5:
                    eb->fParam3 = reinterpret_cast<sLONG_PTR>(*eb->fHandle);
                    break;
                case 6:
                    break;
                default: assert(false && "unexpected handle operation");
            }
            break;
        case EX_CALL_BY_PROCID:
        {
            assert(eb->fParam1 == 42 && eb->fParam2 == 2);
            auto params = reinterpret_cast<PA_Variable *>(*eb->fHandle);
            check(params[1].uValue.fString);
            assert(params[2].uValue.fLongint == notification_update);
            ++calls;
            if (returnKind == 1 || returnKind == 3)
            {
                params[0] = PA_CreateVariable(eVK_Unistring);
                PA_SetUnistring(&params[0].uValue.fString,
                                const_cast<PA_Unichar *>(expected.c_str()));
                assert(!params[0].uValue.fString.fString ||
                       params[0].uValue.fString.fString != params[1].uValue.fString.fString);
            }
            else if (returnKind == 2)
            {
                params[0] = PA_CreateVariable(eVK_ArrayUnicode);
                PA_SetUnistring(reinterpret_cast<PA_Unistring *>(*params[0].uValue.fArray.fData),
                                const_cast<PA_Unichar *>(expected.c_str()));
            }
            eb->fError = returnKind == 3 ? eER_IncompatibleTypes : eER_NoErr;
            break;
        }
        case EX_CONVERT_CHARSET_TO_CHARSET:
        {
            assert(eb->fParam2 == eVTC_UTF_8 && eb->fParam4 == eVTC_UTF_16);
            NSString *text = [[NSString alloc] initWithBytes:eb->fPtr1
                                                    length:eb->fParam1
                                                  encoding:NSUTF8StringEncoding];
            assert(text);
            size_t bytes = [text length] * sizeof(PA_Unichar);
            assert(eb->fParam3 == (eb->fParam1 + 1) * sizeof(PA_Unichar));
            assert(static_cast<size_t>(eb->fParam3) >= bytes);
            [text getCharacters:static_cast<unichar *>(eb->fPtr2)
                          range:NSMakeRange(0, [text length])];
            // The SDK forwards capacities and returns lengths in BYTES, not units.
            eb->fParam3 = bytes;
            eb->fError = 0;
            [text release];
            break;
        }
        case EX_EXECUTE_COMMAND_BY_ID:
        {
            auto params = static_cast<PA_Variable **>(eb->fPtr1);
            if (eb->fParam1 == 678) check(params[0]->uValue.fString);
            else
            {
                assert(eb->fParam1 == 1002);
                check(params[1]->uValue.fString);
            }
            ++calls;
            eb->fError = 0;
            break;
        }
        case EX_CREATE_PICTURE:
        case EX_DUPLICATE_PICTURE:
            // No picture content is needed to exercise string ownership.
            eb->fPicture = nullptr;
            eb->fError = 0;
            break;
        case EX_DISPOSE_PICTURE:
            break;
        default:
            std::cerr << "unexpected engine selector: " << selector << '\n';
            abort();
    }
}

int main(int argc, char **argv)
{
    assert(argc == 3);
    allocatedEmpty = std::string(argv[1]) == "allocated";
    gCall4D = host;
    @autoreleasepool
    {
        for (NSString *text in @[@"", @"calendar", @"caf\u00e9\u65e5", @"event\U0001f600",
                                 @".png", @".jpg", @".tif"])
        {
            C_TEXT fixture;
            fixture.setUTF16String(text);
            expected.resize([text length]);
            if (!expected.empty())
                [text getCharacters:&expected[0] range:NSMakeRange(0, [text length])];
            CUTF16String actualFixture;
            fixture.copyUTF16String(&actualFixture);
            assert(actualFixture == expected);
            const std::string scenario(argv[2]);
            if (scenario == "callback")
            {
                for (int result : {0, 1, 2, 3})
                {
                    returnKind = result;
                    CalendarWatch::notifications.push_back(
                        CalendarWatch::UserInfo(notification_update, text, 42));
                    listenerLoopExecuteMethod();
                    assert(CalendarWatch::notifications.empty());
                    assert(strings.empty() && "callback leaked a string owner");
                }
                listenerLoopExecuteMethod();
            }
            else if (scenario == "file")
            {
                CUTF8String path;
                fixture.copyUTF8String(&path);
                CPicture picture;
                picture.fromFileAtPath(&path);
            }
            else if (scenario == "copy")
            {
                CUTF8String type;
                fixture.copyUTF8String(&type);
                CPicture picture;
                PA_DisposePicture(picture.createCopy(reinterpret_cast<const char *>(type.c_str())));
            }
            else if (scenario == "array")
            {
                PA_Variable array = PA_CreateVariable(eVK_ArrayUnicode);
                BytePtr parameters[] = {reinterpret_cast<BytePtr>(&array)};
                ARRAY_TEXT output;
                output.setSize(1);
                output.appendUTF16String(expected.c_str());
                for (int i = 0; i < 3; ++i)
                {
                    output.toParamAtIndex(parameters, 1);
                    std::vector<std::vector<char>> churn(64, std::vector<char>(256, 42));
                    auto borrowed = PA_GetStringInArray(array, 1);
                    check(borrowed);
                    ARRAY_TEXT copy;
                    copy.fromParamAtIndex(parameters, 1);
                    CUTF16String actual;
                    copy.copyUTF16StringAtIndex(&actual, 1);
                    assert(actual == expected);
                    PA_ResizeArray(&array, 0);
                }
                PA_ClearVariable(&array);
                array = PA_CreateVariable(eVK_ArrayUnicode);
                for (int index : {-1, 1})
                {
                    auto owned = PA_CreateUnistring(const_cast<PA_Unichar *>(expected.c_str()));
                    PA_SetStringInArray(array, index, &owned);
                    check(owned);
                    PA_DisposeUnistring(&owned);
                }
                auto zero = PA_CreateUnistring(const_cast<PA_Unichar *>(expected.c_str()));
                PA_SetStringInArray(array, 0, &zero);
                check(PA_GetStringInArray(array, 0));
                PA_ClearVariable(&array);
                PA_Variable wrong = PA_CreateVariable(eVK_Longint);
                for (int index : {-1, 1})
                {
                    auto owned = PA_CreateUnistring(const_cast<PA_Unichar *>(expected.c_str()));
                    PA_SetStringInArray(wrong, index, &owned);
                    check(owned);
                    PA_DisposeUnistring(&owned);
                }
                PA_Variable missing = {};
                missing.fType = eVK_ArrayUnicode;
                auto owned = PA_CreateUnistring(const_cast<PA_Unichar *>(expected.c_str()));
                PA_SetStringInArray(missing, 0, &owned);
                check(owned);
                PA_DisposeUnistring(&owned);
            }
            else assert(false);
            assert(strings.empty() && "leaked string owner");
            assert(handles.empty() && "leaked handle");
        }
        if (std::string(argv[2]) != "array") assert(calls > 0);
    }
    std::cout << argv[1] << ' ' << argv[2] << ": passed\n";
}
