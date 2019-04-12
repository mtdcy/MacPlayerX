/******************************************************************************
 * Copyright (c) 2016, Chen Fang <mtdcy.chen@gmail.com>
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without 
 * modification, are permitted provided that the following conditions are met:
 *
 * 1. Redistributions of source code must retain the above copyright notice, 
 *    this list of conditions and the following disclaimer.
 *
 * 2. Redistributions in binary form must reproduce the above copyright notice,
 *    this list of conditions and the following disclaimer in the documentation 
 *    and/or other materials provided with the distribution.
 * 
 *  THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
 *  AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE 
 *  IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE 
 *  ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE 
 *  LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR 
 *  CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF 
 *  SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS 
 *  INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN 
 *  CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) 
 *  ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE 
 *  POSSIBILITY OF SUCH DAMAGE.
 ******************************************************************************/


// File:    Message.h
// Author:  mtdcy.chen
// Changes: 
//          1. 20160701     initial version
//

#ifndef _TOOLKIT_HEADERS_MESSAGE_H
#define _TOOLKIT_HEADERS_MESSAGE_H 

#include <ABE/basic/Types.h>
#include <ABE/basic/String.h>
#include <ABE/stl/HashTable.h>

#define MESSAGE_WITH_STL 1

#ifdef __cplusplus
__BEGIN_NAMESPACE_ABE
class __ABE_EXPORT Message : public SharedObject {
    public:
        Message(uint32_t what = 0);
        virtual ~Message();
        Message(const Message&);
        Message& operator=(const Message&);

    public:
        enum Type {
            kTypeInt32,
            kTypeInt64,
            kTypeFloat,
            kTypeDouble,
            kTypePointer,
            kTypeString,
            kTypeObject,
#if MESSAGE_WITH_STL
            kTypeValue,
#endif
        };

    public:
        __ABE_INLINE uint32_t    what        () const { return mWhat; }
        __ABE_INLINE size_t      countEntries() const { return mEntries.size(); }

        void            clear       ();
        bool            contains    (const String& name) const;
        bool            remove      (const String& name);
        String          string      () const;
        bool            contains    (const String& name, Type) const;
        String          getEntryNameAt(size_t index, Type *type) const;

    public:
        // basic types
        void            setInt32    (const String& name, int32_t value);                    // kTypeInt32
        void            setInt64    (const String& name, int64_t value);                    // kTypeInt64
        void            setFloat    (const String& name, float value);                      // kTypeFloat
        void            setDouble   (const String& name, double value);                     // kTypeDouble
        void            setPointer  (const String& name, void *value);                      // kTypePointer
        void            setString   (const String& name, const char *s, size_t len = 0);    // kTypeString
        void            setObject   (const String& name, SharedObject * object);            // kTypeObject

        template <class T> __ABE_INLINE void setObject(const String& name, const Object<T>& o)
        { setObject(name, static_cast<SharedObject *>(o.get())); }

        int32_t         findInt32   (const String& name, int32_t def = 0) const;            // kTypeInt32
        int64_t         findInt64   (const String& name, int64_t def = 0) const;            // kTypeInt64
        float           findFloat   (const String& name, float def = 0) const;              // kTypeFloat
        double          findDouble  (const String& name, double def = 0) const;             // kTypeDouble
        void *          findPointer (const String& name, void * def = NULL) const;          // kTypePointer
        const char *    findString  (const String& name, const char * def = NULL) const;    // kTypeString
        SharedObject *  findObject  (const String& name, SharedObject * def = NULL) const;  // kTypeObject

        // alias
        __ABE_INLINE void setString(const String& name, const String &s)
        { setString(name, s.c_str()); }

    private:
        uint32_t                    mWhat;
        struct Entry {
            Type                    mType;
            union {
                int32_t             i32;
                int64_t             i64;
                float               flt;
                double              dbl;
                void *              ptr;
                SharedObject *      obj;
            } u;
        };

        HashTable<String, Entry>    mEntries;

#if MESSAGE_WITH_STL
    private:
        void            _setValue(const String& name, SharedObject * object);
        SharedObject *  _findValue(const String& name) const;

    public:
        template <class TYPE> struct holder : public SharedObject {
            TYPE    value;
            __ABE_INLINE holder(const TYPE& _value) : SharedObject(), value(_value) { }
            __ABE_INLINE virtual ~holder() { }
        };

        template <class TYPE> __ABE_INLINE void set(const String& name, const TYPE& value)
        { _setValue(name, new holder<TYPE>(value)); }

        // assert if not exists
        template <class TYPE> __ABE_INLINE const TYPE& find(const String& name) const
        { return (static_cast<holder<TYPE> *>(_findValue(name)))->value; }
#endif
};

__END_NAMESPACE_ABE
#endif   // __cplusplus

#ifdef __cplusplus
typedef __NAMESPACE_ABE::Message * MessageRef;
#else
typedef void * MessageRef;
#endif

__BEGIN_DECLS

__ABE_EXPORT MessageRef         SharedMessageCreate();
__ABE_EXPORT MessageRef         SharedMessageCreateWithId(uint32_t id);
__ABE_EXPORT MessageRef         SharedMessageCopy(MessageRef);
#define SharedMessageRetain(x)          (Message *)SharedObjectRetain((SharedObjectRef)x)
#define SharedMessageRelease(x)         SharedObjectRelease((SharedObjectRef)x)
#define SharedMessageGetRetainCount(x)  SharedObjectGetRetainCount((SharedObjectRef)x)

__ABE_EXPORT uint32_t           SharedMessageGetId      (MessageRef);
__ABE_EXPORT size_t             SharedMessageGetCount   (MessageRef);
__ABE_EXPORT bool               SharedMessageContains   (MessageRef, const char *);
__ABE_EXPORT bool               SharedMessageRemove     (MessageRef, const char *);
__ABE_EXPORT void               SharedMessageClear      (MessageRef);

__ABE_EXPORT void               SharedMessagePutInt32   (MessageRef, const char *, int32_t);
__ABE_EXPORT void               SharedMessagePutInt64   (MessageRef, const char *, int64_t);
__ABE_EXPORT void               SharedMessagePutFloat   (MessageRef, const char *, float);
__ABE_EXPORT void               SharedMessagePutDouble  (MessageRef, const char *, double);
__ABE_EXPORT void               SharedMessagePutPointer (MessageRef, const char *, void *);
__ABE_EXPORT void               SharedMessagePutString  (MessageRef, const char *, const char *);
__ABE_EXPORT void               SharedMessagePutObject  (MessageRef, const char *, SharedObjectRef);

__ABE_EXPORT int32_t            SharedMessageGetInt32   (MessageRef, const char *, int32_t);
__ABE_EXPORT int64_t            SharedMessageGetInt64   (MessageRef, const char *, int64_t);
__ABE_EXPORT float              SharedMessageGetFloat   (MessageRef, const char *, float);
__ABE_EXPORT double             SharedMessageGetDouble  (MessageRef, const char *, double);
__ABE_EXPORT void *             SharedMessageGetPointer (MessageRef, const char *, void *);
__ABE_EXPORT const char *       SharedMessageGetString  (MessageRef, const char *, const char *);
__ABE_EXPORT SharedObjectRef    SharedMessageGetObject  (MessageRef, const char *, SharedObjectRef);

__END_DECLS

#endif  // _TOOLKIT_HEADERS_MESSAGE_H

