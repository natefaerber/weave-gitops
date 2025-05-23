package errors

import "errors"

type skippableErr struct {
	Err error
}

func (e skippableErr) Error() string {
	return e.Err.Error()
}

func SkippableErr(err error) skippableErr {
	return skippableErr{Err: err}
}

func IsErrorSkippable(err error) bool {
	var skippableErr skippableErr
	return errors.As(err, &skippableErr)
}
